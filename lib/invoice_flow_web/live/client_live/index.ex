defmodule InvoiceFlowWeb.ClientLive.Index do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Clients

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    clients = Clients.list_clients(user.id)

    {:ok,
     socket
     |> assign(:page_title, "Clients")
     |> assign(:clients, clients)
     |> assign(:search, "")}
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    user = socket.assigns.current_user
    clients = Clients.list_clients(user.id, search: search)
    {:noreply, assign(socket, clients: clients, search: search)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="Clients" subtitle={"#{length(@clients)} clients"}>
      <:actions>
        <.link navigate={~p"/clients/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New Client
        </.link>
      </:actions>
    </.page_header>

    <div class="mb-4">
      <form phx-change="search" phx-submit="search">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="Search clients..."
          class="input input-bordered w-full max-w-xs"
          phx-debounce="300"
        />
      </form>
    </div>

    <%= if @clients == [] do %>
      <.empty_state
        title="No clients yet"
        description="Add your first client to start sending invoices."
        icon="hero-users"
      >
        <:action>
          <.link navigate={~p"/clients/new"} class="btn btn-primary btn-sm">Add Client</.link>
        </:action>
      </.empty_state>
    <% else %>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Email</th>
              <th>Company</th>
              <th>Total Invoiced</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={client <- @clients}
              class="hover cursor-pointer"
              phx-click={JS.navigate(~p"/clients/#{client.id}")}
            >
              <td class="font-medium">{client.name}</td>
              <td>{client.email}</td>
              <td>{client.company || "-"}</td>
              <td><.money amount={client.total_invoiced} currency="USD" /></td>
              <td>
                <.link navigate={~p"/clients/#{client.id}/edit"} class="btn btn-ghost btn-xs">
                  Edit
                </.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end
end
