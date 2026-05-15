defmodule AutoMyInvoiceWeb.InvoiceLive.Show do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Invoices, Reminders, PubSubTopics}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    user = socket.assigns.current_user
    invoice = Invoices.get_invoice!(user.id, id)

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AutoMyInvoice.PubSub, PubSubTopics.invoice_updated(id))
    end

    reminders = Reminders.list_reminders_for_invoice(id)

    {:ok,
     socket
     |> assign(:page_title, invoice.invoice_number)
     |> assign(:invoice, invoice)
     |> assign(:reminders, reminders)}
  end

  @impl true
  def handle_event("send", _params, socket) do
    case Invoices.send_invoice(socket.assigns.invoice) do
      {:ok, invoice} ->
        reminders = Reminders.list_reminders_for_invoice(invoice.id)

        {:noreply,
         socket
         |> assign(:invoice, invoice)
         |> assign(:reminders, reminders)
         |> put_flash(:info, "송장이 발송되었습니다")}

      {:error, :not_draft} ->
        {:noreply, put_flash(socket, :error, "임시저장 상태의 송장만 발송할 수 있습니다")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "송장을 발송할 수 없습니다")}
    end
  end

  @impl true
  def handle_event("mark_paid", _params, socket) do
    case Invoices.mark_as_paid(socket.assigns.invoice) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> assign(:invoice, invoice)
         |> put_flash(:info, "결제완료로 처리되었습니다")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "결제완료 처리에 실패했습니다")}
    end
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Invoices.delete_invoice(socket.assigns.invoice) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "송장이 삭제되었습니다")
         |> push_navigate(to: ~p"/invoices")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "송장을 삭제할 수 없습니다")}
    end
  end

  @impl true
  def handle_info({:invoice_updated, invoice}, socket) do
    reminders = Reminders.list_reminders_for_invoice(invoice.id)

    {:noreply,
     socket
     |> assign(:invoice, invoice)
     |> assign(:reminders, reminders)}
  end

  defp status_actions(status) do
    case status do
      "draft" -> [:send, :edit, :delete]
      "sent" -> [:mark_paid]
      "overdue" -> [:mark_paid]
      _ -> []
    end
  end

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :actions, status_actions(assigns.invoice.status))

    ~H"""
    <.page_header title={@invoice.invoice_number}>
      <:actions>
        <.link
          :if={:edit in @actions}
          navigate={~p"/invoices/#{@invoice.id}/edit"}
          class="btn btn-ghost btn-sm"
        >
          <.icon name="hero-pencil" class="size-4" /> 수정
        </.link>
        <button
          :if={:send in @actions}
          class="btn btn-info btn-sm"
          phx-click="send"
          data-confirm="이 송장을 발송하시겠습니까?"
        >
          <.icon name="hero-paper-airplane" class="size-4" /> 발송
        </button>
        <button
          :if={:mark_paid in @actions}
          class="btn btn-success btn-sm"
          phx-click="mark_paid"
          data-confirm="결제완료로 처리하시겠습니까?"
        >
          <.icon name="hero-check-circle" class="size-4" /> 결제완료
        </button>
        <button
          :if={:delete in @actions}
          class="btn btn-error btn-sm"
          phx-click="delete"
          data-confirm="이 송장을 삭제하시겠습니까?"
        >
          <.icon name="hero-trash" class="size-4" /> 삭제
        </button>
        <.link href={~p"/invoices/#{@invoice.id}/pdf"} class="btn btn-ghost btn-sm" target="_blank">
          <.icon name="hero-arrow-down-tray" class="size-4" /> PDF
        </.link>
        <.link navigate={~p"/invoices"} class="btn btn-ghost btn-sm">← 목록</.link>
      </:actions>
    </.page_header>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
      <div class="card bg-base-100 shadow lg:col-span-2">
        <div class="card-body">
          <h2 class="card-title text-lg">송장 상세</h2>
          <div class="grid grid-cols-2 gap-4 mt-2">
            <div>
              <span class="text-sm text-base-content/60">거래처</span>
              <p>
                <%= if @invoice.client do %>
                  <.link navigate={~p"/clients/#{@invoice.client.id}"} class="link link-primary">
                    {@invoice.client.name}
                  </.link>
                <% else %>
                  -
                <% end %>
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">상태</span>
              <p><.status_badge status={@invoice.status} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">금액</span>
              <p class="text-xl font-bold">
                <.money amount={@invoice.amount} currency={@invoice.currency} />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">지급 기한</span>
              <p><.date_display date={@invoice.due_date} /></p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">작성일</span>
              <p><.date_display date={@invoice.inserted_at} format="short" /></p>
            </div>
            <div :if={@invoice.sent_at}>
              <span class="text-sm text-base-content/60">발송일</span>
              <p><.date_display date={@invoice.sent_at} format="short" /></p>
            </div>
            <div :if={@invoice.paid_at}>
              <span class="text-sm text-base-content/60">결제일</span>
              <p><.date_display date={@invoice.paid_at} format="short" /></p>
            </div>
            <div
              :if={@invoice.paddle_payment_link && @invoice.status in ~w(sent overdue)}
              class="col-span-2"
            >
              <span class="text-sm text-base-content/60">결제 링크</span>
              <p>
                <a
                  href={@invoice.paddle_payment_link}
                  target="_blank"
                  class="link link-primary text-sm break-all"
                >
                  {@invoice.paddle_payment_link}
                </a>
              </p>
            </div>
          </div>
          <div :if={@invoice.notes} class="mt-4">
            <span class="text-sm text-base-content/60">메모</span>
            <p class="whitespace-pre-wrap">{@invoice.notes}</p>
          </div>
        </div>
      </div>

      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">결제 요약</h2>
          <div class="space-y-3 mt-2">
            <div>
              <span class="text-sm text-base-content/60">총액</span>
              <p class="text-xl font-bold">
                <.money amount={@invoice.amount} currency={@invoice.currency} />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">입금액</span>
              <p class="text-xl font-bold text-success">
                <.money amount={@invoice.paid_amount || Decimal.new(0)} currency={@invoice.currency} />
              </p>
            </div>
            <div>
              <span class="text-sm text-base-content/60">잔액</span>
              <p class="text-xl font-bold text-warning">
                <.money
                  amount={
                    Decimal.sub(
                      @invoice.amount || Decimal.new(0),
                      @invoice.paid_amount || Decimal.new(0)
                    )
                  }
                  currency={@invoice.currency}
                />
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>

    <div class="card bg-base-100 shadow mb-6">
      <div class="card-body">
        <h2 class="card-title text-lg">품목</h2>
        <%= if @invoice.items == [] do %>
          <p class="text-base-content/60 mt-2">등록된 품목이 없습니다</p>
        <% else %>
          <div class="overflow-x-auto mt-2">
            <table class="table">
              <thead>
                <tr>
                  <th>품목명</th>
                  <th class="text-right">수량</th>
                  <th class="text-right">단가</th>
                  <th class="text-right">합계</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={item <- @invoice.items}>
                  <td>{item.description}</td>
                  <td class="text-right">{item.quantity}</td>
                  <td class="text-right">
                    <.money amount={item.unit_price} currency={@invoice.currency} />
                  </td>
                  <td class="text-right font-medium">
                    <.money amount={item.total} currency={@invoice.currency} />
                  </td>
                </tr>
              </tbody>
              <tfoot>
                <tr class="font-bold">
                  <td colspan="3" class="text-right">총액</td>
                  <td class="text-right">
                    <.money amount={@invoice.amount} currency={@invoice.currency} />
                  </td>
                </tr>
              </tfoot>
            </table>
          </div>
        <% end %>
      </div>
    </div>

    <div :if={@reminders != []} class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title text-lg">리마인더 타임라인</h2>
        <.timeline>
          <:item
            :for={r <- @reminders}
            title={"#{r.step}단계 리마인더"}
            description={status_text(r)}
            datetime={format_reminder_time(r)}
            status={to_string(reminder_status(r))}
          />
        </.timeline>
      </div>
    </div>
    """
  end

  defp format_reminder_time(r) do
    dt = r.scheduled_at || r.sent_at || r.inserted_at
    if dt, do: Calendar.strftime(dt, "%Y년 %m월 %d일"), else: "-"
  end

  defp status_text(reminder) do
    case reminder.status do
      "pending" -> "예약됨"
      "scheduled" -> "발송 대기 중"
      "sent" -> "발송 완료"
      "opened" -> "수신자가 열람함"
      "clicked" -> "링크 클릭됨"
      "failed" -> "발송 실패"
      "cancelled" -> "취소됨"
      _ -> reminder.status
    end
  end

  defp reminder_status(reminder) do
    case reminder.status do
      s when s in ~w(sent opened clicked) -> :complete
      s when s in ~w(pending scheduled) -> :pending
      _ -> :error
    end
  end
end
