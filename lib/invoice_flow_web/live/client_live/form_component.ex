defmodule InvoiceFlowWeb.ClientLive.FormComponent do
  use InvoiceFlowWeb, :live_component

  alias InvoiceFlow.Clients
  alias InvoiceFlow.Clients.Client

  @timezones [
    {"UTC", "UTC"},
    {"Asia/Seoul", "Asia/Seoul (KST)"},
    {"Asia/Tokyo", "Asia/Tokyo (JST)"},
    {"America/New_York", "America/New_York (EST)"},
    {"America/Los_Angeles", "America/Los_Angeles (PST)"},
    {"America/Chicago", "America/Chicago (CST)"},
    {"Europe/London", "Europe/London (GMT)"},
    {"Europe/Paris", "Europe/Paris (CET)"},
    {"Europe/Berlin", "Europe/Berlin (CET)"},
    {"Australia/Sydney", "Australia/Sydney (AEST)"}
  ]

  @impl true
  def update(%{client: client} = assigns, socket) do
    changeset = Client.changeset(client, %{})

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:timezones, @timezones)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"client" => client_params}, socket) do
    changeset =
      socket.assigns.client
      |> Client.changeset(client_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"client" => client_params}, socket) do
    save_client(socket, socket.assigns.action, client_params)
  end

  defp save_client(socket, :new, client_params) do
    user = socket.assigns.current_user

    case Clients.create_client(user.id, client_params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client created successfully")
         |> push_navigate(to: ~p"/clients/#{client.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_client(socket, :edit, client_params) do
    case Clients.update_client(socket.assigns.client, client_params) do
      {:ok, client} ->
        {:noreply,
         socket
         |> put_flash(:info, "Client updated successfully")
         |> push_navigate(to: ~p"/clients/#{client.id}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="client-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" required />
        <.input field={@form[:email]} type="email" label="Email" required />
        <.input field={@form[:company]} type="text" label="Company" />
        <.input field={@form[:phone]} type="tel" label="Phone" />
        <.input field={@form[:address]} type="text" label="Address" />
        <.input field={@form[:timezone]} type="select" label="Timezone" options={@timezones} />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <:actions>
          <.button type="submit" phx-disable-with="Saving..." class="btn btn-primary">
            Save Client
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
