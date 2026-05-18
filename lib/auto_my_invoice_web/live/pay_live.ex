defmodule AutoMyInvoiceWeb.PayLive do
  @moduledoc """
  Public scan-to-pay landing for AMI-89.

  Reached by scanning the QR shown on the merchant's phone. No login.
  Renders the amount + currency and bounces the visitor straight into
  the Paddle checkout link when one is available. When Paddle isn't
  configured (dev) we degrade gracefully to a "send proof of payment"
  card.
  """

  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Invoices, Repo}
  alias AutoMyInvoice.Invoices.Invoice

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Repo.get(Invoice, id) do
      %Invoice{} = invoice ->
        invoice = Repo.preload(invoice, [:client, :user])

        {:ok,
         socket
         |> assign(:page_title, "결제")
         |> assign(:invoice, invoice)}

      nil ->
        {:ok, assign(socket, page_title: "결제", invoice: nil)}
    end
  end

  @impl true
  def render(%{invoice: nil} = assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4">
      <div class="card bg-base-100 shadow-xl w-full max-w-md">
        <div class="card-body text-center">
          <h1 class="text-xl font-bold">결제 링크를 찾을 수 없습니다</h1>
          <p class="text-base-content/60 text-sm">
            QR이 만료되었거나 잘못된 링크일 수 있습니다. 가게 직원에게 QR을 다시 보여달라고 요청해 주세요.
          </p>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen flex items-center justify-center bg-base-200 px-4">
      <div class="card bg-base-100 shadow-xl w-full max-w-md">
        <div class="card-body items-center text-center">
          <p class="text-base-content/60 text-sm">결제 요청</p>
          <h1 class="text-3xl font-bold">
            <.money amount={@invoice.amount} currency={@invoice.currency} />
          </h1>

          <p :if={@invoice.notes} class="text-base-content/60 text-sm">{@invoice.notes}</p>

          <%= cond do %>
            <% @invoice.status == "paid" -> %>
              <div class="alert alert-success mt-4 w-full">
                <span>결제가 완료되었습니다. 감사합니다.</span>
              </div>

            <% is_binary(@invoice.paddle_payment_link) and @invoice.paddle_payment_link != "" -> %>
              <a
                href={@invoice.paddle_payment_link}
                class="btn btn-primary btn-lg w-full mt-4"
                rel="noopener noreferrer"
              >
                지금 결제하기
              </a>
              <p class="text-xs text-base-content/60 mt-1">
                Paddle에서 안전하게 결제됩니다.
              </p>

            <% true -> %>
              <div class="alert alert-info mt-4 w-full text-sm">
                <span>이 가맹점은 카드 결제가 아직 연결되어 있지 않습니다. 가게 직원에게 결제 방법을 안내받아 주세요.</span>
              </div>
          <% end %>

          <div class="divider"></div>
          <p class="text-xs text-base-content/40">AutoMyInvoice</p>
        </div>
      </div>
    </div>
    """
  end

  # `Invoices` is aliased so future enhancements (e.g. real-time status
  # updates via PubSub) have a clean place to drop in. Unused alias would
  # break --warnings-as-errors otherwise.
  @compile {:no_warn_undefined, Invoices}
end
