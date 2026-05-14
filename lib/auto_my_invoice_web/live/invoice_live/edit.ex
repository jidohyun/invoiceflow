defmodule AutoMyInvoiceWeb.InvoiceLive.Edit do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Invoices

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    if invoice.status != "draft" do
      {:ok,
       socket
       |> put_flash(:error, "임시저장 상태의 송장만 수정할 수 있습니다")
       |> push_navigate(to: ~p"/invoices/#{invoice.id}")}
    else
      {:ok,
       socket
       |> assign(:page_title, "#{invoice.invoice_number} 수정")
       |> assign(:invoice, invoice)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"#{@invoice.invoice_number} 수정"}>
      <:actions>
        <.link navigate={~p"/invoices/#{@invoice.id}"} class="btn btn-ghost btn-sm">← 돌아가기</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-3xl">
      <div class="card-body">
        <.live_component
          module={AutoMyInvoiceWeb.InvoiceLive.FormComponent}
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
