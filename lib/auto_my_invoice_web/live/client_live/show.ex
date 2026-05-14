defmodule AutoMyInvoiceWeb.ClientLive.Show do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Clients, Invoices}

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
         |> put_flash(:info, "거래처가 삭제되었습니다")
         |> push_navigate(to: ~p"/clients")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "거래처를 삭제할 수 없습니다")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={@client.name} subtitle={@client.company}>
      <:actions>
        <.link navigate={~p"/clients/#{@client.id}/edit"} class="btn btn-ghost btn-sm">
          <.icon name="hero-pencil" class="size-4" /> 수정
        </.link>
        <button
          class="btn btn-error btn-sm"
          phx-click="delete"
          data-confirm="이 거래처를 정말 삭제하시겠습니까?"
        >
          <.icon name="hero-trash" class="size-4" /> 삭제
        </button>
      </:actions>
    </.page_header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
      <div class="card bg-base-100 shadow lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title text-lg">연락처 정보</h2>
          <div class="grid grid-cols-2 gap-4 mt-2">
            <div>
              <span class="text-sm text-base-content/60">이메일</span>
              <p>{@client.email}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">전화번호</span>
              <p>{@client.phone || "-"}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">주소</span>
              <p>{@client.address || "-"}</p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">시간대</span>
              <p>{@client.timezone}</p>
            </div>
          </div>
          <div :if={@client.notes} class="mt-4">
            <span class="text-sm text-base-content/60">메모</span>
            <p class="whitespace-pre-wrap">{@client.notes}</p>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">결제 통계</h2>
          <div class="space-y-3 mt-2">
            <div>
              <span class="text-sm text-base-content/60">총 청구액</span>
              <p class="text-xl font-bold">
                <.money amount={@client.total_invoiced} currency="KRW" />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">총 수금액</span>
              <p class="text-xl font-bold text-success">
                <.money amount={@client.total_paid} currency="KRW" />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">평균 결제 소요일</span>
              <p class="text-xl font-bold">{@client.avg_payment_days || "-"}</p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <div class="flex justify-between items-center">
          <h2 class="card-title text-lg">송장</h2>
          <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm">
            <.icon name="hero-plus" class="size-4" /> 새 송장
          </.link>
        </div>

        <%= if @invoices == [] do %>
          <.empty_state
            title="송장 없음"
            description="이 거래처에 발행된 송장이 아직 없습니다."
            icon="hero-document-text"
          />
        <% else %>
          <div class="overflow-x-auto mt-4">
            <table class="table">
              <thead>
                <tr>
                  <th>송장 번호</th>
                  <th>금액</th>
                  <th>상태</th>
                  <th>지급 기한</th>
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
