defmodule InvoiceFlowWeb.InvoiceLive.Edit do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Invoices

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    if invoice.status != "draft" do
      {:ok,
       socket
       |> put_flash(:error, "Only draft invoices can be edited")
       |> push_navigate(to: ~p"/invoices/#{invoice.id}")}
    else
      {:ok,
       socket
       |> assign(:page_title, "Edit #{invoice.invoice_number}")
       |> assign(:invoice, invoice)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"Edit #{@invoice.invoice_number}"}>
      <:actions>
        <.link navigate={~p"/invoices/#{@invoice.id}"} class="btn btn-ghost btn-sm">← Back</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-3xl">
      <div class="card-body">
        <.live_component
          module={InvoiceFlowWeb.InvoiceLive.FormComponent}
          id="edit-invoice"
          action={:edit}
          invoice={@invoice}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end
end
