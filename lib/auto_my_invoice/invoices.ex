defmodule AutoMyInvoice.Invoices do
  @moduledoc "송장 관리 Context"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.PubSubTopics
  alias AutoMyInvoice.Reminders
  alias AutoMyInvoice.Emails.InvoiceEmail
  alias AutoMyInvoice.Mailer
  alias AutoMyInvoice.Billing.PaddleClient
  alias AutoMyInvoice.Clients

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

  @spec create_invoice(Accounts.User.t(), map()) ::
          {:ok, Invoice.t()} | {:error, :plan_limit | Ecto.Changeset.t()}
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

  ## AMI-89 — 즉시 송장 (현장 QR 결제)

  @walk_in_email "walk-in@auto-my-invoice.internal"

  @doc """
  Create a single-line "instant invoice" without picking a client first.
  Used by the on-the-spot QR flow: enter amount → generate QR → customer
  scans → Paddle payment link.

  Invoices need a `client_id`, so we (idempotently) get-or-create a
  per-user "Walk-in customer" client and attach this invoice to it.
  The invoice is created in `sent` status so the Paddle link is available
  immediately for the QR.
  """
  @spec create_quick_invoice(Accounts.User.t(), map()) ::
          {:ok, Invoice.t()} | {:error, :plan_limit | Ecto.Changeset.t()}
  def create_quick_invoice(user, attrs) do
    walk_in = ensure_walk_in_client!(user.id)

    full_attrs =
      attrs
      |> Map.put(:client_id, walk_in.id)
      |> Map.put_new(:due_date, Date.utc_today())
      |> Map.put(:status, "sent")
      |> Map.put(:sent_at, DateTime.truncate(DateTime.utc_now(), :second))

    case create_invoice(user, full_attrs) do
      {:ok, invoice} ->
        invoice = maybe_create_payment_link(Repo.preload(invoice, [:client, :user]))
        {:ok, invoice}

      error ->
        error
    end
  end

  defp ensure_walk_in_client!(user_id) do
    case Clients.get_client_by_email(user_id, @walk_in_email) do
      %Clients.Client{} = c ->
        c

      nil ->
        {:ok, c} =
          Clients.create_client(user_id, %{
            name: "워크인 고객",
            email: @walk_in_email
          })

        c
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
    multi =
      Ecto.Multi.new()
      |> Ecto.Multi.update(
        :mark_sent,
        invoice
        |> Invoice.status_changeset("sent")
        |> Ecto.Changeset.put_change(:sent_at, DateTime.truncate(DateTime.utc_now(), :second))
      )
      |> Ecto.Multi.run(:schedule_reminders, fn _repo, %{mark_sent: sent_invoice} ->
        sent_invoice = Repo.preload(sent_invoice, :client)
        Reminders.schedule_reminders(sent_invoice)
      end)

    case Repo.transaction(multi) do
      {:ok, %{mark_sent: sent_invoice}} ->
        broadcast_invoice_change(sent_invoice)
        sent_invoice = maybe_create_payment_link(Repo.preload(sent_invoice, [:client, :user]))

        email =
          InvoiceEmail.invoice_sent(%{
            invoice: sent_invoice,
            client: sent_invoice.client,
            from_email: sender_email(),
            user: sent_invoice.user
          })

        Mailer.deliver(email)
        {:ok, sent_invoice}

      {:error, :mark_sent, changeset, _} ->
        {:error, changeset}

      {:error, :schedule_reminders, reason, _} ->
        {:error, reason}
    end
  end

  @spec mark_as_paid(Invoice.t(), DateTime.t()) :: {:ok, Invoice.t()}
  def mark_as_paid(%Invoice{} = invoice, paid_at \\ DateTime.utc_now()) do
    paid_at = DateTime.truncate(paid_at, :second)

    result =
      invoice
      |> Invoice.mark_paid_changeset(paid_at)
      |> Repo.update()
      |> tap_ok(&broadcast_invoice_change/1)

    with {:ok, updated} <- result do
      Reminders.cancel_pending_reminders(invoice.id)
      AutoMyInvoice.Clients.recalculate_stats(updated.client_id)
      result
    end
  end

  @spec record_payment(Invoice.t(), map()) :: {:ok, Invoice.t()} | {:error, atom()}
  def record_payment(%Invoice{status: status}, _attrs)
      when status not in ["sent", "overdue", "partially_paid"] do
    {:error, :invalid_status}
  end

  def record_payment(%Invoice{} = invoice, %{"amount" => amount}) do
    amount = to_decimal(amount)
    remaining = Decimal.sub(invoice.amount, invoice.paid_amount)

    cond do
      Decimal.compare(amount, Decimal.new(0)) != :gt ->
        {:error, :invalid_amount}

      Decimal.compare(amount, remaining) == :gt ->
        {:error, :overpayment}

      true ->
        multi =
          Ecto.Multi.new()
          |> Ecto.Multi.update_all(
            :atomic_update,
            from(i in Invoice,
              where: i.id == ^invoice.id,
              update: [set: [paid_amount: fragment("? + ?", i.paid_amount, ^amount)]]
            ),
            []
          )
          |> Ecto.Multi.run(:invoice, fn repo, _changes ->
            {:ok, repo.get!(Invoice, invoice.id)}
          end)
          |> Ecto.Multi.run(:transition, fn repo, %{invoice: updated} ->
            if Decimal.compare(updated.paid_amount, updated.amount) != :lt do
              updated
              |> Ecto.Changeset.change(
                status: "paid",
                paid_at: DateTime.truncate(DateTime.utc_now(), :second)
              )
              |> repo.update()
            else
              updated
              |> Ecto.Changeset.change(
                status: "partially_paid",
                overdue_notified_at: nil
              )
              |> repo.update()
            end
          end)

        case Repo.transaction(multi) do
          {:ok, %{transition: updated}} ->
            if updated.status == "paid" do
              Reminders.cancel_pending_reminders(updated.id)
            end

            broadcast_invoice_change(updated)
            AutoMyInvoice.Clients.recalculate_stats(updated.client_id)
            {:ok, updated}

          {:error, _, reason, _} ->
            {:error, reason}
        end
    end
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_binary(n), do: Decimal.new(n)

  @spec mark_as_overdue(Invoice.t()) :: {:ok, Invoice.t()}
  def mark_as_overdue(%Invoice{status: status} = invoice)
      when status in ["sent", "partially_paid"] do
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
        overdue_total:
          sum(
            fragment(
              "CASE WHEN ? = 'overdue' THEN ? - ? ELSE 0 END",
              i.status,
              i.amount,
              i.paid_amount
            )
          ),
        overdue_count:
          fragment("CAST(SUM(CASE WHEN ? = 'overdue' THEN 1 ELSE 0 END) AS integer)", i.status)
      }
    )
    |> Repo.one()
  end

  @doc """
  Returns {total_outstanding_amount, overdue_count, primary_currency} for invoices with status sent or overdue.
  The primary_currency is the most frequently used currency among outstanding invoices.
  """
  @spec total_outstanding(map()) :: {Decimal.t(), non_neg_integer(), String.t()}
  def total_outstanding(user) do
    # AMI-90: sum across currencies using the cached KRW amount. Falls back
    # to :amount when :amount_krw is nil (no FX rate cached yet) so KRW-only
    # accounts keep working before the first FX refresh.
    result =
      from(i in Invoice,
        where: i.user_id == ^user.id,
        where: i.status in ~w(sent overdue),
        select: %{
          total: coalesce(sum(coalesce(i.amount_krw, i.amount)), ^Decimal.new(0)),
          overdue_count:
            fragment(
              "CAST(SUM(CASE WHEN ? = 'overdue' THEN 1 ELSE 0 END) AS integer)",
              i.status
            )
        }
      )
      |> Repo.one()

    {result.total || Decimal.new(0), result.overdue_count || 0, "KRW"}
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

  defp maybe_filter_client(query, client_id),
    do: from(i in query, where: i.client_id == ^client_id)

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

  defp maybe_create_payment_link(%Invoice{} = invoice) do
    case PaddleClient.create_payment_link(%{invoice: invoice, client: invoice.client}) do
      {:ok, url} when url != "" ->
        {:ok, updated} = update_invoice(invoice, %{paddle_payment_link: url})
        updated

      _ ->
        invoice
    end
  end

  defp sender_email do
    Application.get_env(:auto_my_invoice, :sender_email, "noreply@automyinvoice.app")
  end

  defp broadcast_invoice_change(%Invoice{} = invoice) do
    Phoenix.PubSub.broadcast(
      AutoMyInvoice.PubSub,
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
