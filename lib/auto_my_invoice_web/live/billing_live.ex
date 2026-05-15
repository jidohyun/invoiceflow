defmodule AutoMyInvoiceWeb.BillingLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.Billing

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    usage = Billing.usage_summary(user.id)
    subscription = Billing.get_active_subscription(user.id)

    {:ok,
     socket
     |> assign(:page_title, "결제")
     |> assign(:usage, usage)
     |> assign(:subscription, subscription)
     |> assign(:plans, Billing.plans())
     |> assign(:ordered_plans, Billing.plans_ordered())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="결제 및 구독" />

    <div class="max-w-4xl space-y-6">
      <%!-- Current Plan --%>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">현재 플랜</h2>
          <div class="flex items-center gap-4 mt-2">
            <span class={"badge badge-lg #{plan_badge_class(@usage.plan)}"}>
              {@usage.plan_name}
            </span>
            <%= if @subscription do %>
              <span class="text-sm text-base-content/60">
                {Calendar.strftime(@subscription.inserted_at, "%Y년 %m월 %d일")} 부터 이용 중
              </span>
            <% end %>
          </div>

          <%!-- Usage --%>
          <%= if @usage.invoices_limit != :unlimited do %>
            <div class="mt-4">
              <div class="flex justify-between text-sm mb-1">
                <span>이번 달 송장</span>
                <span class="font-medium">{@usage.invoices_used} / {@usage.invoices_limit}</span>
              </div>
              <progress
                class={"progress #{if @usage.usage_percent >= 100, do: "progress-error", else: "progress-primary"} w-full"}
                value={@usage.usage_percent}
                max="100"
              />
              <%= if !@usage.can_create do %>
                <p class="text-sm text-error mt-2">
                  이번 달 한도에 도달했습니다. 더 많은 송장을 발행하려면 업그레이드하세요.
                </p>
              <% end %>
            </div>
          <% else %>
            <p class="text-sm text-success mt-4 flex items-center">
              <span class="material-icons text-sm mr-1">all_inclusive</span> 무제한 송장
            </p>
          <% end %>
        </div>
      </div>

      <%!-- Plans --%>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div
          :for={{plan_id, plan} <- @ordered_plans}
          class={"card bg-base-100 shadow #{if @usage.plan == plan_id, do: "ring-2 ring-primary"}"}
        >
          <div class="card-body">
            <h3 class="card-title">{plan.name}</h3>
            <p class="text-3xl font-bold mt-2">
              US${plan.price}<span class="text-sm font-normal text-base-content/60">/월</span>
            </p>
            <ul class="mt-4 space-y-2 text-sm">
              <li class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span>
                월 {format_limit(plan.monthly_invoices)} 송장
              </li>
              <li :if={plan_id != "free"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span> AI 리마인더
              </li>
              <li :if={plan_id != "free"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span> 결제 연동
              </li>
              <li :if={plan_id == "pro"} class="flex items-center gap-2">
                <span class="material-icons text-success text-sm">check</span> 팀 및 API 이용
              </li>
            </ul>
            <div class="card-actions mt-4">
              <%= cond do %>
                <% @usage.plan == plan_id -> %>
                  <button class="btn btn-outline btn-sm w-full" disabled>현재 플랜</button>
                <% plan_id == "free" -> %>
                  <button class="btn btn-ghost btn-sm w-full" disabled>무료</button>
                <% true -> %>
                  <button
                    class="btn btn-primary btn-sm w-full"
                    phx-click="upgrade"
                    phx-value-plan={plan_id}
                  >
                    {plan.name} 플랜으로 {if plan.price > (@plans[@usage.plan] || %{price: 0}).price,
                      do: "업그레이드",
                      else: "변경"}
                  </button>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <%!-- Subscription Details --%>
      <div :if={@subscription} class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">구독 상세</h2>
          <div class="grid grid-cols-2 gap-4 mt-2 text-sm">
            <div>
              <span class="text-base-content/60">상태</span>
              <p class="font-medium">{subscription_status(@subscription.status)}</p>
            </div>
            <div>
              <span class="text-base-content/60">플랜</span>
              <p class="font-medium">{@subscription.plan}</p>
            </div>
            <div :if={@subscription.current_period_end}>
              <span class="text-base-content/60">다음 결제일</span>
              <p class="font-medium">
                {Calendar.strftime(@subscription.current_period_end, "%Y년 %m월 %d일")}
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("upgrade", %{"plan" => _plan}, socket) do
    # In production, this would open Paddle Checkout overlay
    # For now, show a flash message
    {:noreply, put_flash(socket, :info, "Paddle 결제창이 열립니다. 프로덕션에서는 PADDLE_API_KEY를 설정하세요.")}
  end

  defp plan_badge_class("free"), do: "badge-ghost"
  defp plan_badge_class("starter"), do: "badge-primary"
  defp plan_badge_class("pro"), do: "badge-secondary"
  defp plan_badge_class(_), do: "badge-ghost"

  defp format_limit(:unlimited), do: "무제한"
  defp format_limit(n), do: to_string(n)

  defp subscription_status("active"), do: "활성"
  defp subscription_status("trialing"), do: "체험 중"
  defp subscription_status("past_due"), do: "연체"
  defp subscription_status("cancelled"), do: "취소됨"
  defp subscription_status("canceled"), do: "취소됨"
  defp subscription_status(other), do: other
end
