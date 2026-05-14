defmodule AutoMyInvoiceWeb.InvoiceLive.FormComponent do
  use AutoMyInvoiceWeb, :live_component

  alias AutoMyInvoice.{Invoices, Clients, Accounts}
  alias AutoMyInvoice.Invoices.Invoice

  @currencies [
    {"KRW - 대한민국 원", "KRW"},
    {"USD - 미국 달러", "USD"},
    {"EUR - 유로", "EUR"},
    {"JPY - 일본 엔", "JPY"},
    {"GBP - 영국 파운드", "GBP"}
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
         |> put_flash(:info, "송장이 생성되었습니다")
         |> push_navigate(to: ~p"/invoices/#{invoice.id}")}

      {:error, :plan_limit} ->
        {:noreply, put_flash(socket, :error, "이번 달 송장 한도에 도달했습니다. 플랜을 업그레이드하세요.")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_invoice(socket, :edit, invoice_params) do
    case Invoices.update_invoice(socket.assigns.invoice, invoice_params) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "송장이 수정되었습니다")
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
          <span>무료 플랜의 이번 달 송장 한도에 도달했습니다. 더 많은 송장을 생성하려면 업그레이드하세요.</span>
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
            label="거래처"
            options={[{"거래처를 선택하세요...", ""} | @client_options]}
            required
          />
          <.input field={@form[:currency]} type="select" label="통화" options={@currencies} />
        </div>

        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <.input field={@form[:due_date]} type="date" label="지급 기한" required />
          <.input field={@form[:amount]} type="number" label="총 금액" step="0.01" required />
        </div>

        <.input field={@form[:notes]} type="textarea" label="메모" />

        <div class="divider">품목</div>

        <div class="space-y-3">
          <.inputs_for :let={item_form} field={@form[:items]}>
            <div class="flex gap-2 items-end">
              <div class="flex-1">
                <.input field={item_form[:description]} type="text" label="품목명" placeholder="품목명을 입력하세요" />
              </div>
              <div class="w-20">
                <.input field={item_form[:quantity]} type="number" label="수량" step="0.01" min="0" />
              </div>
              <div class="w-28">
                <.input field={item_form[:unit_price]} type="number" label="단가" step="0.01" min="0" />
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
          <.icon name="hero-plus" class="size-4" /> 품목 추가
        </button>

        <:actions>
          <.button
            type="submit"
            phx-disable-with="저장 중..."
            class="btn btn-primary"
            disabled={!@can_create && @action == :new}
          >
            {if @action == :new, do: "송장 생성", else: "송장 수정"}
          </.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end
end
