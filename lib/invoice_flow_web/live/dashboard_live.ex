defmodule InvoiceFlowWeb.DashboardLive do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.{Invoices, Reminders, PubSubTopics}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, PubSubTopics.user_invoices(user.id))
    end

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> load_dashboard_data(user)}
  end

  @impl true
  def handle_info({:invoice_updated, _invoice}, socket) do
    {:noreply, load_dashboard_data(socket, socket.assigns.current_user)}
  end

  defp load_dashboard_data(socket, user) do
    {outstanding_amount, overdue_count} = Invoices.total_outstanding(user)
    rate = Invoices.collection_rate(user)
    recent_invoices = Invoices.recent_invoices(user)
    active_reminders = Reminders.count_active_reminders(user.id)

    socket
    |> assign(:outstanding_amount, outstanding_amount)
    |> assign(:overdue_count, overdue_count)
    |> assign(:collection_rate, rate)
    |> assign(:recent_invoices, recent_invoices)
    |> assign(:active_reminders, active_reminders)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Header --%>
    <header class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <h2 class="text-3xl font-semibold font-display">Overview</h2>
      <div class="flex items-center gap-3">
        <span class="flex items-center text-sm font-medium text-success bg-success/10 px-3 py-1 rounded-full">
          <span class="w-2 h-2 rounded-full bg-success mr-2 animate-pulse"></span>
          Live
        </span>
        <.link navigate={~p"/upload"} class="btn btn-ghost btn-sm btn-circle">
          <span class="material-icons text-base-content/60">notifications</span>
        </.link>
        <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm gap-1">
          <.icon name="hero-plus" class="size-4" /> New Invoice
        </.link>
      </div>
    </header>

    <%!-- KPI Cards --%>
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">Total Outstanding</h3>
        <p class="text-3xl font-bold">{format_dashboard_money(@outstanding_amount)}</p>
        <p class="text-sm text-error mt-2 flex items-center">
          <span class="material-icons text-sm mr-1">trending_up</span>
          {to_string(@overdue_count)} overdue
        </p>
      </div>

      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">Collection Rate</h3>
        <p class="text-3xl font-bold">{@collection_rate}%</p>
        <div class="w-full bg-base-200 rounded-full h-2 mt-4">
          <div
            class="bg-primary h-2 rounded-full transition-all duration-500"
            style={"width: #{@collection_rate}%"}
          >
          </div>
        </div>
      </div>

      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">Active Reminders</h3>
        <p class="text-3xl font-bold">{to_string(@active_reminders)}</p>
        <p class="text-sm text-success mt-2 flex items-center">
          <span class="material-icons text-sm mr-1">schedule</span>
          Automated follow-ups
        </p>
      </div>
    </div>

    <%!-- Upload Zone --%>
    <.link
      navigate={~p"/upload"}
      class="block bg-base-100 p-8 rounded-xl shadow-sm border-2 border-dashed border-base-300 mb-8 text-center hover:border-primary transition-colors cursor-pointer group"
    >
      <span class="material-icons text-5xl text-base-content/30 group-hover:text-primary transition-colors mb-4">
        cloud_upload
      </span>
      <h3 class="text-lg font-medium mb-1">Drag & Drop Invoices Here</h3>
      <p class="text-base-content/60 text-sm mb-4">or click to browse files (PDF, PNG, JPG)</p>
      <span class="btn btn-primary btn-sm pointer-events-none">Select Files</span>
    </.link>

    <%!-- Recent Invoices Table --%>
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 overflow-hidden">
      <div class="px-6 py-4 border-b border-base-300 flex justify-between items-center">
        <h3 class="text-lg font-semibold">Recent Invoices</h3>
        <.link navigate={~p"/invoices"} class="text-primary text-sm font-medium hover:underline">
          View All
        </.link>
      </div>

      <%= if @recent_invoices == [] do %>
        <.empty_state
          title="No invoices yet"
          description="Create your first invoice to get started."
          icon="hero-document-text"
        >
          <:action>
            <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm">
              Create Invoice
            </.link>
          </:action>
        </.empty_state>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-base-200 text-base-content/60 text-xs uppercase tracking-wider">
                <th class="px-6 py-3 font-medium">Invoice #</th>
                <th class="px-6 py-3 font-medium">Client</th>
                <th class="px-6 py-3 font-medium">Amount</th>
                <th class="px-6 py-3 font-medium">Due Date</th>
                <th class="px-6 py-3 font-medium">Status</th>
                <th class="px-6 py-3 font-medium text-right">Actions</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-300">
              <tr
                :for={invoice <- @recent_invoices}
                class="hover:bg-base-200/50 transition-colors cursor-pointer"
                phx-click={JS.navigate(~p"/invoices/#{invoice.id}")}
              >
                <td class="px-6 py-4 font-medium font-mono text-sm">{invoice.invoice_number}</td>
                <td class="px-6 py-4">{if(invoice.client, do: invoice.client.name, else: "-")}</td>
                <td class="px-6 py-4 font-medium">
                  <.money amount={invoice.amount} currency={invoice.currency} />
                </td>
                <td class={"px-6 py-4 #{if overdue?(invoice), do: "text-error font-medium", else: "text-base-content/60"}"}>
                  <.date_display date={invoice.due_date} format="short" />
                </td>
                <td class="px-6 py-4">
                  <.invoice_status_pill status={invoice.status} />
                </td>
                <td class="px-6 py-4 text-right">
                  <button class="text-base-content/40 hover:text-primary transition-colors">
                    <span class="material-icons text-sm">more_vert</span>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp invoice_status_pill(assigns) do
    ~H"""
    <span class={"px-2.5 py-1 text-xs font-medium rounded-full #{pill_class(@status)}"}>
      {format_status(@status)}
    </span>
    """
  end

  defp pill_class("paid"), do: "bg-success/10 text-success"
  defp pill_class("sent"), do: "bg-info/10 text-info"
  defp pill_class("overdue"), do: "bg-error/10 text-error"
  defp pill_class("partially_paid"), do: "bg-warning/10 text-warning"
  defp pill_class("draft"), do: "bg-base-content/10 text-base-content/60"
  defp pill_class("cancelled"), do: "bg-base-content/10 text-base-content/40"
  defp pill_class(_), do: "bg-base-content/10 text-base-content/60"

  defp format_status(status) do
    status |> String.replace("_", " ") |> String.capitalize()
  end

  defp overdue?(%{status: "overdue"}), do: true
  defp overdue?(%{due_date: nil}), do: false

  defp overdue?(%{due_date: due_date, status: status}) when status not in ~w(paid cancelled) do
    Date.compare(due_date, Date.utc_today()) == :lt
  end

  defp overdue?(_), do: false

  defp format_dashboard_money(nil), do: "$0"

  defp format_dashboard_money(%Decimal{} = amount) do
    "$#{Decimal.round(amount, 2) |> Decimal.to_string(:normal)}"
  end

  defp format_dashboard_money(amount), do: "$#{amount}"
end
