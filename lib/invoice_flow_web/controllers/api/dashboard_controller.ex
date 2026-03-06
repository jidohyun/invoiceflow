defmodule InvoiceFlowWeb.Api.DashboardController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Invoices
  alias InvoiceFlowWeb.Api.JsonHelpers

  def index(conn, _params) do
    user = conn.assigns.current_user

    {outstanding_amount, overdue_count} = Invoices.total_outstanding(user)
    rate = Invoices.collection_rate(user)
    collected = Invoices.collected_this_month(user.id)

    json(conn, %{
      data: %{
        outstanding_amount: outstanding_amount,
        overdue_count: overdue_count,
        collection_rate: rate,
        collected_this_month: collected
      }
    })
  end

  def recent(conn, params) do
    user = conn.assigns.current_user
    limit = params |> Map.get("limit", "5") |> String.to_integer() |> min(20)
    invoices = Invoices.recent_invoices(user, limit)

    json(conn, %{
      data: Enum.map(invoices, &JsonHelpers.render_invoice/1)
    })
  end
end
