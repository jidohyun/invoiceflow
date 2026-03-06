defmodule InvoiceFlowWeb.Api.InvoiceController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Invoices
  alias InvoiceFlowWeb.Api.{JsonHelpers, FallbackController}

  action_fallback FallbackController

  def index(conn, params) do
    user = conn.assigns.current_user

    opts =
      []
      |> maybe_put(:status, params["status"])
      |> maybe_put(:client_id, params["client_id"])
      |> maybe_put(:search, params["q"])

    invoices = Invoices.list_invoices(user.id, opts)
    counts = Invoices.count_by_status(user.id)

    json(conn, %{
      data: Enum.map(invoices, &JsonHelpers.render_invoice/1),
      meta: %{total: counts["all"] || 0, counts: counts}
    })
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)
    json(conn, %{data: JsonHelpers.render_invoice(invoice)})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"invoice" => invoice_params}) do
    user = conn.assigns.current_user

    case Invoices.create_invoice(user, invoice_params) do
      {:ok, invoice} ->
        invoice = Invoices.get_invoice!(user.id, invoice.id)

        conn
        |> put_status(:created)
        |> json(%{data: JsonHelpers.render_invoice(invoice)})

      error ->
        error
    end
  end

  def update(conn, %{"id" => id, "invoice" => invoice_params}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    case Invoices.update_invoice(invoice, invoice_params) do
      {:ok, updated} ->
        updated = Invoices.get_invoice!(user.id, updated.id)
        json(conn, %{data: JsonHelpers.render_invoice(updated)})

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    case Invoices.delete_invoice(invoice) do
      {:ok, _} ->
        conn |> put_status(:no_content) |> text("")

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def send_invoice(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    case Invoices.send_invoice(invoice) do
      {:ok, sent} ->
        sent = Invoices.get_invoice!(user.id, sent.id)
        json(conn, %{data: JsonHelpers.render_invoice(sent)})

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def mark_paid(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    case Invoices.mark_as_paid(invoice) do
      {:ok, paid} ->
        paid = Invoices.get_invoice!(user.id, paid.id)
        json(conn, %{data: JsonHelpers.render_invoice(paid)})

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
