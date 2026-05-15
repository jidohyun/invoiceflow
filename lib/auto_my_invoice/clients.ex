defmodule AutoMyInvoice.Clients do
  @moduledoc "클라이언트 관리 Context"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Clients.Client

  ## 조회

  @spec list_clients(binary(), keyword()) :: [Client.t()]
  def list_clients(user_id, opts \\ []) do
    sort_by = Keyword.get(opts, :sort_by, :name)
    sort_order = Keyword.get(opts, :sort_order, :asc)
    search = Keyword.get(opts, :search)

    from(c in Client, where: c.user_id == ^user_id)
    |> maybe_search(search)
    |> order_by([c], [{^sort_order, field(c, ^sort_by)}])
    |> Repo.all()
  end

  @spec get_client!(binary(), binary()) :: Client.t()
  def get_client!(user_id, id) do
    Client
    |> Repo.get_by!(id: id, user_id: user_id)
  end

  @spec get_client_by_email(binary(), String.t()) :: Client.t() | nil
  def get_client_by_email(user_id, email) do
    Repo.get_by(Client, user_id: user_id, email: email)
  end

  ## 생성

  @spec create_client(binary(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def create_client(user_id, attrs) do
    %Client{user_id: user_id}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  ## 수정

  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  ## 삭제

  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  ## 통계 재계산

  @spec recalculate_stats(binary()) :: {:ok, Client.t()}
  def recalculate_stats(client_id) do
    alias AutoMyInvoice.Invoices.Invoice

    invoices =
      from(i in Invoice, where: i.client_id == ^client_id)
      |> Repo.all()

    total_invoiced =
      invoices
      |> Enum.reduce(Decimal.new(0), fn inv, acc -> Decimal.add(acc, inv.amount) end)

    total_paid =
      invoices
      |> Enum.reduce(Decimal.new(0), fn inv, acc -> Decimal.add(acc, inv.paid_amount) end)

    avg_payment_days =
      invoices
      |> Enum.filter(fn inv ->
        inv.status == "paid" and inv.sent_at != nil and inv.paid_at != nil
      end)
      |> case do
        [] ->
          nil

        paid_invoices ->
          total_days =
            paid_invoices
            |> Enum.map(fn inv -> DateTime.diff(inv.paid_at, inv.sent_at, :second) end)
            |> Enum.map(fn seconds -> div(seconds, 86_400) end)
            |> Enum.sum()

          div(total_days, length(paid_invoices))
      end

    client = Repo.get!(Client, client_id)

    client
    |> Client.stats_changeset(%{
      total_invoiced: total_invoiced,
      total_paid: total_paid,
      avg_payment_days: avg_payment_days
    })
    |> Repo.update()
  end

  ## 분석

  alias AutoMyInvoice.Invoices.Invoice

  @doc "Calculate on-time rate for a client (paid within due_date + 3 days)"
  @spec on_time_rate(binary()) :: float()
  def on_time_rate(client_id) do
    paid_invoices =
      from(i in Invoice,
        where: i.client_id == ^client_id,
        where: i.status == "paid",
        where: not is_nil(i.paid_at),
        where: not is_nil(i.due_date)
      )
      |> Repo.all()

    case paid_invoices do
      [] ->
        0.0

      invoices ->
        on_time_count =
          invoices
          |> Enum.count(fn inv ->
            grace_date = Date.add(inv.due_date, 3)
            paid_date = DateTime.to_date(inv.paid_at)
            Date.compare(paid_date, grace_date) != :gt
          end)

        Float.round(on_time_count * 100.0 / length(invoices), 1)
    end
  end

  @doc "Client ranking by payment speed (ascending = best payers first)"
  @spec client_ranking(binary()) :: [map()]
  def client_ranking(user_id) do
    # Get clients with at least 2 paid invoices
    client_ids_with_enough_paid =
      from(i in Invoice,
        where: i.status == "paid",
        join: c in Client,
        on: c.id == i.client_id,
        where: c.user_id == ^user_id,
        group_by: i.client_id,
        having: count(i.id) >= 2,
        select: i.client_id
      )
      |> Repo.all()

    client_ids_with_enough_paid
    |> Enum.map(fn client_id ->
      client = Repo.get!(Client, client_id)
      analytics = client_analytics(client_id)

      %{
        id: client.id,
        name: client.name,
        avg_payment_days: analytics.avg_payment_days,
        total_invoiced: analytics.total_invoiced,
        total_paid: analytics.total_paid,
        on_time_rate: analytics.on_time_rate
      }
    end)
    |> Enum.sort_by(fn entry -> entry.avg_payment_days || 999_999 end, :asc)
  end

  @doc "Single client analytics"
  @spec client_analytics(binary()) :: map()
  def client_analytics(client_id) do
    invoices =
      from(i in Invoice, where: i.client_id == ^client_id)
      |> Repo.all()

    paid_invoices =
      Enum.filter(invoices, fn inv ->
        inv.status == "paid" and inv.sent_at != nil and inv.paid_at != nil
      end)

    total_invoiced =
      invoices
      |> Enum.reduce(Decimal.new(0), fn inv, acc -> Decimal.add(acc, inv.amount) end)

    total_paid =
      invoices
      |> Enum.reduce(Decimal.new(0), fn inv, acc -> Decimal.add(acc, inv.paid_amount) end)

    outstanding_amount = Decimal.sub(total_invoiced, total_paid)

    avg_payment_days =
      case paid_invoices do
        [] ->
          nil

        _ ->
          total_days =
            paid_invoices
            |> Enum.map(fn inv -> DateTime.diff(inv.paid_at, inv.sent_at, :second) end)
            |> Enum.map(fn seconds -> div(seconds, 86_400) end)
            |> Enum.sum()

          div(total_days, length(paid_invoices))
      end

    invoice_count = length(invoices)
    paid_count = length(Enum.filter(invoices, &(&1.status == "paid")))

    %{
      avg_payment_days: avg_payment_days,
      total_invoiced: total_invoiced,
      total_paid: total_paid,
      on_time_rate: on_time_rate(client_id),
      invoice_count: invoice_count,
      paid_count: paid_count,
      outstanding_amount: outstanding_amount
    }
  end

  ## 내부

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search) do
    term = "%#{search}%"

    from(c in query,
      where: ilike(c.name, ^term) or ilike(c.email, ^term) or ilike(c.company, ^term)
    )
  end
end
