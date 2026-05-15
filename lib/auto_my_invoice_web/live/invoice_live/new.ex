defmodule AutoMyInvoiceWeb.InvoiceLive.New do
  use AutoMyInvoiceWeb, :live_view

  @impl true
  def mount(params, _session, socket) do
    prefill =
      case params do
        %{"extraction_job_id" => job_id} ->
          job = AutoMyInvoice.Extraction.get_job!(job_id)

          if job.status == "completed" do
            # Extraction.to_invoice_attrs/1 expects the string-keyed
            # `extracted_data` map produced by the AI client — NOT the
            # ExtractionJob struct itself. Passing the struct here would
            # cause Access.get/3 to raise on Elixir 1.19+ because Ecto
            # schemas do not implement the Access behaviour.
            AutoMyInvoice.Extraction.to_invoice_attrs(job.extracted_data || %{})
          else
            %{}
          end

        _ ->
          %{}
      end

    {:ok,
     socket
     |> assign(:page_title, "새 송장")
     |> assign(:prefill, prefill)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="새 송장">
      <:actions>
        <.link navigate={~p"/invoices"} class="btn btn-ghost btn-sm">← 목록</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-3xl">
      <div class="card-body">
        <.live_component
          module={AutoMyInvoiceWeb.InvoiceLive.FormComponent}
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
