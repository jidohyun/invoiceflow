defmodule InvoiceFlowWeb.InvoiceLive.FormComponent do
  use InvoiceFlowWeb, :live_component

  alias InvoiceFlow.{Invoices, Clients, Accounts}
  alias InvoiceFlow.Invoices.Invoice

  @currencies [
    {"USD - US Dollar", "USD"},
    {"EUR - Euro", "EUR"},
    {"KRW - Korean Won", "KRW"},
    {"GBP - British Pound", "GBP"},
    {"JPY - Japanese Yen", "JPY"}
  ]

  @impl true
  def update(assigns, socket) do
    user = assigns.current_user
    clients = Clients.list_clients(user.id)
    client_options = Enum.map(clients, &{&1.name, &1.id})

    changeset =
      case assigns.action do
        :new ->
          attrs = Map.get(assigns, :prefill, %{})
          Invoice.create_changeset(%Invoice{user_id: user.id}, attrs)

        :edit ->
          Invoice.update_changeset(assigns.invoice, %{})
      end

    can_create = Accounts.can_create_invoice?(user)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:currencies, @currencies)
     |> assign(:client_options, client_options)
     |> assign(:can_create, can_create)
     |> assign_form(changeset)}
  end

  @impl true
  def handle_event("validate", %{"invoice" => invoice_params}, socket) do
    changeset =
      case socket.assigns.action do
        :new ->
          %Invoice{user_id: socket.assigns.current_user.id}
          |> Invoice.create_changeset(invoice_params)

        :edit ->
          socket.assigns.invoice
          |> Invoice.update_changeset(invoice_params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"invoice" => invoice_params}, socket) do
    save_invoice(socket, socket.assigns.action, invoice_params)
  end

  @impl true
  def handle_event("add_item", _params, socket) do
    form = socket.assigns.form
    items = form.params["items"] || %{}

    next_index =
      items
      |> Map.keys()
      |> Enum.map(&String.to_integer/1)
      |> Enum.max(fn -> -1 end)
      |> Kernel.+(1)

    new_items =
      Map.put(items, to_string(next_index), %{
        "description" => "",
        "quantity" => "1",
        "unit_price" => ""
      })

    params = Map.put(form.params, "items", new_items)

    changeset =
      case socket.assigns.action do
        :new ->
          %Invoice{user_id: socket.assigns.current_user.id}
          |> Invoice.create_changeset(params)

        :edit ->
          socket.assigns.invoice
          |> Invoice.update_changeset(params)
      end
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  defp save_invoice(socket, :new, invoice_params) do
    user = socket.assigns.current_user

    case Invoices.create_invoice(user, invoice_params) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invoice created successfully")
         |> push_navigate(to: ~p"/invoices/#{invoice.id}")}

      {:error, :plan_limit} ->
        {:noreply, put_flash(socket, :error, "You've reached your monthly invoice limit. Upgrade your plan.")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_invoice(socket, :edit, invoice_params) do
    case Invoices.update_invoice(socket.assigns.invoice, invoice_params) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invoice updated successfully")
         |> push_navigate(to: ~p"/invoices/#{invoice.id}")}

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
      <%= if !@can_create && @action == :new do %>
        <div class="alert alert-warning mb-4">
          <.icon name="hero-exclamation-triangle" class="size-5" />
          <span>You've reached your monthly invoice limit on the Free plan. Upgrade to create more invoices.</span>
        </div>
      <% end %>

      <.simple_form
        for={@form}
        id="invoice-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input
            field={@form[:client_id]}
            type="select"
            label="Client"
            options={[{"Select a client...", ""} | @client_options]}
            required
          />
          <.input field={@form[:currency]} type="select" label="Currency" options={@currencies} />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input field={@form[:due_date]} type="date" label="Due Date" required />
          <.input field={@form[:amount]} type="number" label="Total Amount" step="0.01" required />
        </div>

        <.input field={@form[:notes]} type="textarea" label="Notes" />

        <div class="divider">Line Items</div>

        <div class="space-y-3">
          <.inputs_for :let={item_form} field={@form[:items]}>
            <div class="flex gap-2 items-end">
              <div class="flex-1">
                <.input field={item_form[:description]} type="text" label="Description" placeholder="Item description" />
              </div>
              <div class="w-20">
                <.input field={item_form[:quantity]} type="number" label="Qty" step="0.01" min="0" />
              </div>
              <div class="w-28">
                <.input field={item_form[:unit_price]} type="number" label="Unit Price" step="0.01" min="0" />
              </div>
              <div class="w-10 pb-2">
                <button
                  type="button"
                  name={"invoice[items_drop][]"}
                  value={item_form.index}
                  class="btn btn-ghost btn-sm btn-circle"
                  phx-click={JS.dispatch("change")}
                >
                  <.icon name="hero-x-mark" class="size-4" />
                </button>
              </div>
            </div>
          </.inputs_for>
        </div>

        <input type="hidden" name="invoice[items_sort][]" />

        <button
          type="button"
          class="btn btn-ghost btn-sm mt-2"
          phx-click="add_item"
          phx-target={@myself}
        >
          <.icon name="hero-plus" class="size-4" /> Add Item
        </button>

        <:actions>
          <.button
            type="submit"
            phx-disable-with="Saving..."
            class="btn btn-primary"
            disabled={!@can_create && @action == :new}
          >
            {if @action == :new, do: "Create Invoice", else: "Update Invoice"}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
