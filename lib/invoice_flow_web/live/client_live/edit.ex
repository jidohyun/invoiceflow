defmodule InvoiceFlowWeb.ClientLive.Edit do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Clients

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    client = Clients.get_client!(user.id, id)

    {:ok,
     socket
     |> assign(:page_title, "Edit #{client.name}")
     |> assign(:client, client)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"Edit #{@client.name}"}>
      <:actions>
        <.link navigate={~p"/clients/#{@client.id}"} class="btn btn-ghost btn-sm">← Back</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-2xl">
      <div class="card-body">
        <.live_component
          module={InvoiceFlowWeb.ClientLive.FormComponent}
          id="edit-client"
          client={@client}
          action={:edit}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end
end
