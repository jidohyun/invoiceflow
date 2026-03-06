defmodule InvoiceFlow.Invoices do
  @moduledoc "송장 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Invoices.Invoice
  alias InvoiceFlow.Accounts
  alias InvoiceFlow.PubSubTopics
  alias InvoiceFlow.Reminders
  alias InvoiceFlow.Emails.InvoiceEmail
  alias InvoiceFlow.Mailer

  ## 조회

  @spec list_invoices(binary(), keyword()) :: [Invoice.t()]
  def list_invoices(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    client_id = Keyword.get(opts, :client_id)
    search = Keyword.get(opts, :search)
    sort_by = Keyword.get(opts, :sort_by, :due_date)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    from(i in Invoice,
      where: i.user_id == ^user_id,
      preload: [:client, :items]
    )
    |> maybe_filter_status(status)
    |> maybe_filter_client(client_id)
    |> maybe_filter_search(search)
    |> order_by([i], [{^sort_order, field(i, ^sort_by)}])
    |> Repo.all()
  end

  @spec count_by_status(binary()) :: %{String.t() => non_neg_integer()}
  def count_by_status(user_id) do
    rows =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        group_by: i.status,
        select: {i.status, count(i.id)}
      )
      |> Repo.all()

    counts = Map.new(rows)
    total = counts |> Map.values() |> Enum.sum()
    Map.put(counts, "all", total)
  end

  @spec get_invoice!(binary(), binary()) :: Invoice.t()
  def get_invoice!(user_id, id) do
    Invoice
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload([:client, :items])
  end

  ## 생성

  @spec create_invoice(Accounts.User.t(), map()) :: {:ok, Invoice.t()} | {:error, :plan_limit | Ecto.Changeset.t()}
  def create_invoice(user, attrs) do
    if Accounts.can_create_invoice?(user) do
      %Invoice{user_id: user.id}
      |> Invoice.create_changeset(attrs)
      |> Repo.insert()
      |> tap_ok(&broadcast_invoice_change/1)
    else
      {:error, :plan_limit}
    end
  end

  ## 수정

  @spec update_invoice(Invoice.t(), map()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def update_invoice(%Invoice{} = invoice, attrs) do
    invoice
    |> Invoice.update_changeset(attrs)
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  ## 상태 전환

  @spec mark_as_sent(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def mark_as_sent(%Invoice{} = invoice) do
    invoice
    |> Invoice.status_changeset("sent")
    |> Ecto.Changeset.put_change(:sent_at, DateTime.truncate(DateTime.utc_now(), :second))
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  @spec send_invoice(Invoice.t()) ::
          {:ok, Invoice.t()} | {:error, :not_draft | Ecto.Changeset.t()}
  def send_invoice(%Invoice{status: status} = _invoice) when status != "draft" do
    {:error, :not_draft}
  end

  def send_invoice(%Invoice{} = invoice) do
    with {:ok, sent_invoice} <- mark_as_sent(invoice),
         {:ok, _reminders} <- Reminders.schedule_reminders(sent_invoice),
         from_email <- sender_email(),
         email <- InvoiceEmail.invoice_sent(%{
           invoice: sent_invoice,
           client: sent_invoice.client,
           from_email: from_email
         }) do
      Mailer.deliver(email)
      {:ok, sent_invoice}
    end
  end

  @spec mark_as_paid(Invoice.t(), DateTime.t()) :: {:ok, Invoice.t()}
  def mark_as_paid(%Invoice{} = invoice, paid_at \\ DateTime.utc_now()) do
    paid_at = DateTime.truncate(paid_at, :second)

    invoice
    |> Invoice.mark_paid_changeset(paid_at)
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  @spec mark_as_overdue(Invoice.t()) :: {:ok, Invoice.t()}
  def mark_as_overdue(%Invoice{status: "sent"} = invoice) do
    invoice
    |> Invoice.status_changeset("overdue")
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  ## 삭제

  @spec delete_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, :cannot_delete_non_draft}
  def delete_invoice(%Invoice{status: "draft"} = invoice) do
    Repo.delete(invoice)
  end

  def delete_invoice(_invoice), do: {:error, :cannot_delete_non_draft}

  ## 집계

  @spec outstanding_summary(binary()) :: map()
  def outstanding_summary(user_id) do
    from(i in Invoice,
      where: i.user_id == ^user_id,
      where: i.status in ~w(sent overdue partially_paid),
      select: %{
        total: coalesce(sum(i.amount - i.paid_amount), 0),
        count: count(i.id),
        overdue_total: sum(fragment("CASE WHEN ? = 'overdue' THEN ? - ? ELSE 0 END",
          i.status, i.amount, i.paid_amount)),
        overdue_count: fragment("CAST(SUM(CASE WHEN ? = 'overdue' THEN 1 ELSE 0 END) AS integer)", i.status)
      }
    )
    |> Repo.one()
  end

  @doc """
  Returns {total_outstanding_amount, overdue_count} for invoices with status sent or overdue.
  """
  @spec total_outstanding(map()) :: {Decimal.t(), non_neg_integer()}
  def total_outstanding(user) do
    result =
      from(i in Invoice,
        where: i.user_id == ^user.id,
        where: i.status in ~w(sent overdue),
        select: %{
          total: coalesce(sum(i.amount), ^Decimal.new(0)),
          overdue_count:
            fragment(
              "CAST(SUM(CASE WHEN ? = 'overdue' THEN 1 ELSE 0 END) AS integer)",
              i.status
            )
        }
      )
      |> Repo.one()

    {result.total || Decimal.new(0), result.overdue_count || 0}
  end

  @doc """
  Returns collection rate as an integer percentage: paid_amount / total_amount * 100.
  Returns 0 when there are no invoices.
  """
  @spec collection_rate(map()) :: integer()
  def collection_rate(user) do
    result =
      from(i in Invoice,
        where: i.user_id == ^user.id,
        select: %{
          total: coalesce(sum(i.amount), ^Decimal.new(0)),
          paid: coalesce(sum(i.paid_amount), ^Decimal.new(0))
        }
      )
      |> Repo.one()

    total = Decimal.to_float(result.total || Decimal.new(0))
    paid = Decimal.to_float(result.paid || Decimal.new(0))

    if total == 0.0, do: 0, else: round(paid / total * 100)
  end

  @doc """
  Returns the N most recent invoices for a user, preloaded with client.
  """
  @spec recent_invoices(map(), pos_integer()) :: [Invoice.t()]
  def recent_invoices(user, limit \\ 5) do
    from(i in Invoice,
      where: i.user_id == ^user.id,
      order_by: [desc: i.inserted_at],
      limit: ^limit,
      preload: [:client]
    )
    |> Repo.all()
  end

  ## 이번 달 수금액

  @spec collected_this_month(binary()) :: Decimal.t()
  def collected_this_month(user_id) do
    start_of_month = Date.utc_today() |> Date.beginning_of_month()

    from(i in Invoice,
      where: i.user_id == ^user_id,
      where: i.status == "paid",
      where: fragment("?::date", i.paid_at) >= ^start_of_month,
      select: coalesce(sum(i.paid_amount), 0)
    )
    |> Repo.one()
  end

  ## Private

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: from(i in query, where: i.status == ^status)

  defp maybe_filter_client(query, nil), do: query
  defp maybe_filter_client(query, client_id), do: from(i in query, where: i.client_id == ^client_id)

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) do
    term = "%#{search}%"

    from(i in query,
      left_join: c in assoc(i, :client),
      where:
        ilike(i.invoice_number, ^term) or
          ilike(c.name, ^term) or
          ilike(i.notes, ^term)
    )
  end

  defp sender_email do
    Application.get_env(:invoice_flow, :sender_email, "noreply@invoiceflow.app")
  end

  defp broadcast_invoice_change(%Invoice{} = invoice) do
    Phoenix.PubSub.broadcast(
      InvoiceFlow.PubSub,
      PubSubTopics.user_invoices(invoice.user_id),
      {:invoice_updated, invoice}
    )
  end

  defp tap_ok({:ok, result} = ok, func) do
    func.(result)
    ok
  end

  defp tap_ok(error, _func), do: error
end
