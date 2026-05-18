defmodule AutoMyInvoiceWeb.InvoiceLive.Quick do
  @moduledoc """
  "Instant invoice" flow for face-to-face sales (AMI-89).

  Merchant enters an amount + currency → a one-line invoice is created in
  `sent` status against the per-user walk-in client → a QR code linking
  to the public `/pay/:id` page is rendered, ready to show on the phone.

  When Paddle credentials are configured the invoice already carries the
  payment link by the time it lands in `:invoice`. Otherwise the QR still
  works — the public `/pay/:id` page falls back to a plain "send proof of
  payment to the merchant" message.
  """

  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Invoices, QR}

  @currencies ~w(KRW USD EUR JPY GBP)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "즉시 송장")
     |> assign(:currencies, @currencies)
     |> assign(:invoice, nil)
     |> assign(:qr_data_url, nil)
     |> assign(:pay_url, nil)
     |> assign(:form, to_form(%{"amount" => "", "currency" => "KRW", "notes" => ""}, as: "quick"))}
  end

  @impl true
  def handle_event("generate", %{"quick" => params}, socket) do
    user = socket.assigns.current_user

    attrs = %{
      amount: params["amount"],
      currency: params["currency"] || "KRW",
      notes: params["notes"]
    }

    case Invoices.create_quick_invoice(user, attrs) do
      {:ok, invoice} ->
        pay_url = url(~p"/pay/#{invoice.id}")

        {:noreply,
         socket
         |> assign(:invoice, invoice)
         |> assign(:pay_url, pay_url)
         |> assign(:qr_data_url, QR.to_data_url(pay_url))
         |> put_flash(:info, "QR을 손님에게 보여주세요. 결제 완료 시 자동으로 paid 상태가 됩니다.")}

      {:error, :plan_limit} ->
        {:noreply,
         put_flash(socket, :error, "이번 달 송장 발행 한도에 도달했습니다. 결제 플랜을 확인해 주세요.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, as: "quick"))}
    end
  end

  def handle_event("reset", _params, socket) do
    {:noreply,
     socket
     |> assign(:invoice, nil)
     |> assign(:qr_data_url, nil)
     |> assign(:pay_url, nil)
     |> assign(:form, to_form(%{"amount" => "", "currency" => "KRW", "notes" => ""}, as: "quick"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="즉시 송장" />

    <div class="max-w-md mx-auto space-y-6">
      <div :if={@invoice == nil} class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">금액 입력</h2>
          <p class="text-base-content/60 text-sm mb-4">
            현장에서 손님에게 보여줄 QR을 만듭니다. 손님이 스캔하면 결제 페이지가 열립니다.
          </p>

          <.form for={@form} phx-submit="generate" class="space-y-4">
            <div>
              <label for="quick_amount" class="block text-sm font-medium mb-1">금액</label>
              <input
                type="number"
                step="1"
                min="1"
                required
                name="quick[amount]"
                id="quick_amount"
                inputmode="decimal"
                class="input input-bordered w-full"
                placeholder="예: 12000"
              />
            </div>

            <div>
              <label for="quick_currency" class="block text-sm font-medium mb-1">통화</label>
              <select
                name="quick[currency]"
                id="quick_currency"
                class="select select-bordered w-full"
              >
                <option :for={c <- @currencies} value={c} selected={c == "KRW"}>
                  {c}
                </option>
              </select>
            </div>

            <div>
              <label for="quick_notes" class="block text-sm font-medium mb-1">메모 (선택)</label>
              <input
                type="text"
                name="quick[notes]"
                id="quick_notes"
                maxlength="120"
                class="input input-bordered w-full"
                placeholder="예: 테이블 7번"
              />
            </div>

            <button type="submit" class="btn btn-primary w-full" phx-disable-with="QR 생성 중...">
              QR 생성
            </button>
          </.form>
        </div>
      </div>

      <div :if={@invoice} class="card bg-base-100 shadow">
        <div class="card-body items-center text-center">
          <h2 class="card-title text-lg">손님에게 보여주세요</h2>
          <img src={@qr_data_url} alt="결제 QR" class="w-64 h-64 mt-2" />
          <p class="text-base-content/60 text-xs mt-2 break-all">{@pay_url}</p>

          <div class="divider"></div>

          <p class="text-sm">
            <span class="text-base-content/60">금액</span>
            <span class="font-medium ml-1">
              <.money amount={@invoice.amount} currency={@invoice.currency} />
            </span>
          </p>
          <p :if={@invoice.notes} class="text-xs text-base-content/60">{@invoice.notes}</p>

          <div class="flex gap-2 mt-4 w-full">
            <button type="button" class="btn btn-ghost flex-1" phx-click="reset">
              새 QR 만들기
            </button>
            <.link navigate={~p"/invoices/#{@invoice.id}"} class="btn btn-primary flex-1">
              송장 상세
            </.link>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
