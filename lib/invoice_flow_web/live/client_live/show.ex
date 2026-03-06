defmodule InvoiceFlowWeb.ClientLive.Show do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.{Clients, Invoices}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    client = Clients.get_client!(user.id, id)
    invoices = Invoices.list_invoices(user.id, client_id: id)

    {:ok,
     socket
     |> assign(:page_title, client.name)
     |> assign(:client, client)
     |> assign(:invoices, invoices)}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Clients.delete_client(socket.assigns.client) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client deleted")
         |> push_navigate(to: ~p"/clients")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete client")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={@client.name} subtitle={@client.company}>
      <:actions>
        <.link navigate={~p"/clients/#{@client.id}/edit"} class="btn btn-ghost btn-sm">
          <.icon name="hero-pencil" class="size-4" /> Edit
        </.link>
        <button
          class="btn btn-error btn-sm"
          phx-click="delete"
          data-confirm="Are you sure you want to delete this client?"
        >
          <.icon name="hero-trash" class="size-4" /> Delete
        </button>
      </:actions>
    </.page_header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
      <div class="card bg-base-100 shadow lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title text-lg">Contact Information</h2>
          <div class="grid grid-cols-2 gap-4 mt-2">
            <div>
              <span class="text-sm text-base-content/60">Email</span>
              <p>{@client.email}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Phone</span>
              <p>{@client.phone || "-"}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Address</span>
              <p>{@client.address || "-"}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Timezone</span>
              <p>{@client.timezone}</p>
            </div>
          </div>
          <div :if={@client.notes} class="mt-4">
            <span class="text-sm text-base-content/60">Notes</span>
            <p class="whitespace-pre-wrap">{@client.notes}</p>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">Payment Stats</h2>
          <div class="space-y-3 mt-2">
            <div>
              <span class="text-sm text-base-content/60">Total Invoiced</span>
              <p class="text-xl font-bold">
                <.money amount={@client.total_invoiced} currency="USD" />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Total Paid</span>
              <p class="text-xl font-bold text-success">
                <.money amount={@client.total_paid} currency="USD" />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">Avg Payment Days</span>
              <p class="text-xl font-bold">{@client.avg_payment_days || "-"}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <div class="flex justify-between items-center">
          <h2 class="card-title text-lg">Invoices</h2>
          <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> New Invoice
          </.link>
        </div>

        <%= if @invoices == [] do %>
          <.empty_state
            title="No invoices"
            description="No invoices for this client yet."
            icon="hero-document-text"
          />
        <% else %>
          <div class="overflow-x-auto mt-4">
            <table class="table">
              <thead>
                <tr>
                  <th>Invoice #</th>
                  <th>Amount</th>
                  <th>Status</th>
                  <th>Due Date</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={inv <- @invoices}
                  class="hover cursor-pointer"
                  phx-click={JS.navigate(~p"/invoices/#{inv.id}")}
                >
                  <td class="font-mono text-sm">{inv.invoice_number}</td>
                  <td><.money amount={inv.amount} currency={inv.currency} /></td>
                  <td><.status_badge status={inv.status} /></td>
                  <td><.date_display date={inv.due_date} /></td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
