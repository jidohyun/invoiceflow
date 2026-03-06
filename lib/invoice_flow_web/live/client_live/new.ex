defmodule InvoiceFlowWeb.ClientLive.New do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Clients.Client

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New Client")
     |> assign(:client, %Client{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="New Client">
      <:actions>
        <.link navigate={~p"/clients"} class="btn btn-ghost btn-sm">← Back</.link>
      </:actions>
    </.page_header>

    <div class="card bg-base-100 shadow max-w-2xl">
      <div class="card-body">
        <.live_component
          module={InvoiceFlowWeb.ClientLive.FormComponent}
          id="new-client"
          client={@client}
          action={:new}
          current_user={@current_user}
        />
      </div>
    </div>
    """
  end
end
