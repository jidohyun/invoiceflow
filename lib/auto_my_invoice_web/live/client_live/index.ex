defmodule AutoMyInvoiceWeb.ClientLive.Index do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Clients

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    clients = Clients.list_clients(user.id)

    {:ok,
     socket
     |> assign(:page_title, "거래처")
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
    <.page_header title="거래처" subtitle={"거래처 #{length(@clients)}곳"}>
      <:actions>
        <.link navigate={~p"/clients/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> 새 거래처
        </.link>
      </:actions>
    </.page_header>

    <div class="mb-4">
      <form phx-change="search" phx-submit="search">
        <input
          type="text"
          name="search"
          value={@search}
          placeholder="거래처 검색..."
          class="input input-bordered w-full max-w-xs"
          phx-debounce="300"
        />
      </form>
    </div>

    <%= if @clients == [] do %>
      <.empty_state
        title="등록된 거래처가 없습니다"
        description="첫 거래처를 등록하고 송장을 발행해 보세요."
        icon="hero-users"
      >
        <:action>
          <.link navigate={~p"/clients/new"} class="btn btn-primary btn-sm">거래처 추가</.link>
        </:action>
      </.empty_state>
    <% else %>
      <div class="overflow-x-auto">
        <table class="table">
          <thead>
            <tr>
              <th>이름</th>
              <th>이메일</th>
              <th>회사</th>
              <th>총 청구액</th>
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
              <td><.money amount={client.total_invoiced} currency="KRW" /></td>
              <td>
                <.link navigate={~p"/clients/#{client.id}/edit"} class="btn btn-ghost btn-xs">
                  수정
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
