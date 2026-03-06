defmodule InvoiceFlowWeb.InvoiceLive.New do
  use InvoiceFlowWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    prefill =
      case params do
        %{"extraction_job_id" => job_id} ->
          job = InvoiceFlow.Extraction.get_job!(job_id)

          if job.status == "completed" do
            InvoiceFlow.Extraction.to_invoice_attrs(job)
          else
            %{}
          end

        _ ->
          %{}
      end

    {:ok,
     socket
     |> assign(:page_title, "New Invoice")
     |> assign(:prefill, prefill)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="New Invoice">
      <:actions>
        <.link navigate={~p"/invoices"} class="btn btn-ghost btn-sm">← Back</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-3xl">
      <div class="card-body">
        <.live_component
          module={InvoiceFlowWeb.InvoiceLive.FormComponent}
          id="new-invoice"
          action={:new}
          current_user={@current_user}
          prefill={@prefill}
        />
      </div>
    </div>
    """
  end
end
