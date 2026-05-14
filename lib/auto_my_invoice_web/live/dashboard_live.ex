defmodule AutoMyInvoiceWeb.DashboardLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Invoices, Reminders, Billing, PubSubTopics}

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AutoMyInvoice.PubSub, PubSubTopics.user_invoices(user.id))
    end

    usage = Billing.usage_summary(user.id)

    {:ok,
     socket
     |> assign(:page_title, "대시보드")
     |> assign(:usage, usage)
     |> load_dashboard_data(user)}
  end

  @impl true
  def handle_info({:invoice_updated, _invoice}, socket) do
    {:noreply, load_dashboard_data(socket, socket.assigns.current_user)}
  end

  defp load_dashboard_data(socket, user) do
    {outstanding_amount, overdue_count, primary_currency} = Invoices.total_outstanding(user)
    rate = Invoices.collection_rate(user)
    recent_invoices = Invoices.recent_invoices(user)
    active_reminders = Reminders.count_active_reminders(user.id)

    socket
    |> assign(:outstanding_amount, outstanding_amount)
    |> assign(:outstanding_currency, primary_currency)
    |> assign(:overdue_count, overdue_count)
    |> assign(:collection_rate, rate)
    |> assign(:recent_invoices, recent_invoices)
    |> assign(:active_reminders, active_reminders)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <%!-- Header --%>
    <header class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-8">
      <h2 class="text-3xl font-semibold font-display">한눈에 보기</h2>
      <div class="flex items-center gap-3">
        <span class="flex items-center text-sm font-medium text-success bg-success/10 px-3 py-1 rounded-full">
          <span class="w-2 h-2 rounded-full bg-success mr-2 animate-pulse"></span>
          실시간
        </span>
        <.link navigate={~p"/upload"} class="btn btn-ghost btn-sm btn-circle">
          <span class="material-icons text-base-content/60">notifications</span>
        </.link>
        <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm gap-1">
          <.icon name="hero-plus" class="size-4" /> 새 송장
        </.link>
      </div>
    </header>

    <%!-- KPI Cards --%>
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">미수금 총액</h3>
        <p class="text-3xl font-bold">
          <.money amount={@outstanding_amount} currency={@outstanding_currency} />
        </p>
        <p class="text-sm text-error mt-2 flex items-center">
          <span class="material-icons text-sm mr-1">trending_up</span>
          연체 {to_string(@overdue_count)}건
        </p>
      </div>

      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">수금률</h3>
        <p class="text-3xl font-bold">{@collection_rate}%</p>
        <div class="w-full bg-base-200 rounded-full h-2 mt-4">
          <div
            class="bg-primary h-2 rounded-full transition-all duration-500"
            style={"width: #{@collection_rate}%"}
          >
          </div>
        </div>
      </div>

      <div class="bg-base-100 p-6 rounded-xl shadow-sm border border-base-300">
        <h3 class="text-base-content/60 text-sm font-medium mb-2">진행 중인 리마인더</h3>
        <p class="text-3xl font-bold">{to_string(@active_reminders)}</p>
        <p class="text-sm text-success mt-2 flex items-center">
          <span class="material-icons text-sm mr-1">schedule</span>
          자동 팔로업
        </p>
      </div>
    </div>

    <%!-- Usage Widget --%>
    <%= if @usage.invoices_limit != :unlimited do %>
      <div class="bg-base-100 p-4 rounded-xl shadow-sm border border-base-300 mb-8 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <span class="material-icons text-primary">receipt_long</span>
          <div>
            <p class="text-sm font-medium">
              이번 달 송장: <span class="font-bold">{@usage.invoices_used}/{@usage.invoices_limit}</span>
            </p>
            <progress
              class={"progress #{if @usage.usage_percent >= 100, do: "progress-error", else: "progress-primary"} w-48 h-2"}
              value={@usage.usage_percent}
              max="100"
            />
          </div>
        </div>
        <%= if !@usage.can_create do %>
          <.link navigate={~p"/settings/billing"} class="btn btn-primary btn-sm">
            플랜 업그레이드
          </.link>
        <% else %>
          <.link navigate={~p"/settings/billing"} class="btn btn-ghost btn-sm text-primary">
            {@usage.plan_name} 플랜
          </.link>
        <% end %>
      </div>
    <% end %>

    <%!-- Upload Zone --%>
    <.link
      navigate={~p"/upload"}
      class="block bg-base-100 p-8 rounded-xl shadow-sm border-2 border-dashed border-base-300 mb-8 text-center hover:border-primary transition-colors cursor-pointer group"
    >
      <span class="material-icons text-5xl text-base-content/30 group-hover:text-primary transition-colors mb-4">
        cloud_upload
      </span>
      <h3 class="text-lg font-medium mb-1">여기로 송장 파일을 끌어다 놓으세요</h3>
      <p class="text-base-content/60 text-sm mb-4">또는 클릭해서 파일 선택 (PDF, PNG, JPG)</p>
      <span class="btn btn-primary btn-sm pointer-events-none">파일 선택</span>
    </.link>

    <%!-- Recent Invoices Table --%>
    <div class="bg-base-100 rounded-xl shadow-sm border border-base-300 overflow-hidden">
      <div class="px-6 py-4 border-b border-base-300 flex justify-between items-center">
        <h3 class="text-lg font-semibold">최근 송장</h3>
        <.link navigate={~p"/invoices"} class="text-primary text-sm font-medium hover:underline">
          전체 보기
        </.link>
      </div>

      <%= if @recent_invoices == [] do %>
        <.empty_state
          title="아직 송장이 없습니다"
          description="첫 송장을 발행해 시작해 보세요."
          icon="hero-document-text"
        >
          <:action>
            <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm">
              송장 만들기
            </.link>
          </:action>
        </.empty_state>
      <% else %>
        <div class="overflow-x-auto">
          <table class="w-full text-left border-collapse">
            <thead>
              <tr class="bg-base-200 text-base-content/60 text-xs uppercase tracking-wider">
                <th class="px-6 py-3 font-medium">송장 번호</th>
                <th class="px-6 py-3 font-medium">거래처</th>
                <th class="px-6 py-3 font-medium">금액</th>
                <th class="px-6 py-3 font-medium">지급 기한</th>
                <th class="px-6 py-3 font-medium">상태</th>
                <th class="px-6 py-3 font-medium text-right">작업</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-base-300">
              <tr
                :for={invoice <- @recent_invoices}
                class="hover:bg-base-200/50 transition-colors cursor-pointer"
                phx-click={JS.navigate(~p"/invoices/#{invoice.id}")}
              >
                <td class="px-6 py-4 font-medium font-mono text-sm">{invoice.invoice_number}</td>
                <td class="px-6 py-4">{if(invoice.client, do: invoice.client.name, else: "-")}</td>
                <td class="px-6 py-4 font-medium">
                  <.money amount={invoice.amount} currency={invoice.currency} />
                </td>
                <td class={"px-6 py-4 #{if overdue?(invoice), do: "text-error font-medium", else: "text-base-content/60"}"}>
                  <.date_display date={invoice.due_date} format="short" />
                </td>
                <td class="px-6 py-4">
                  <.invoice_status_pill status={invoice.status} />
                </td>
                <td class="px-6 py-4 text-right">
                  <button class="text-base-content/40 hover:text-primary transition-colors">
                    <span class="material-icons text-sm">more_vert</span>
                  </button>
                </td>
              </tr>
            </tbody>
          </table>
        </div>
      <% end %>
    </div>
    """
  end

  defp invoice_status_pill(assigns) do
    ~H"""
    <span class={"px-2.5 py-1 text-xs font-medium rounded-full #{pill_class(@status)}"}>
      {format_status(@status)}
    </span>
    """
  end

  defp pill_class("paid"), do: "bg-success/10 text-success"
  defp pill_class("sent"), do: "bg-info/10 text-info"
  defp pill_class("overdue"), do: "bg-error/10 text-error"
  defp pill_class("partially_paid"), do: "bg-warning/10 text-warning"
  defp pill_class("draft"), do: "bg-base-content/10 text-base-content/60"
  defp pill_class("cancelled"), do: "bg-base-content/10 text-base-content/40"
  defp pill_class(_), do: "bg-base-content/10 text-base-content/60"

  defp format_status("paid"), do: "결제완료"
  defp format_status("sent"), do: "발송"
  defp format_status("overdue"), do: "연체"
  defp format_status("partially_paid"), do: "부분결제"
  defp format_status("draft"), do: "임시저장"
  defp format_status("cancelled"), do: "취소"
  defp format_status(status), do: status

  defp overdue?(%{status: "overdue"}), do: true
  defp overdue?(%{due_date: nil}), do: false

  defp overdue?(%{due_date: due_date, status: status}) when status not in ~w(paid cancelled) do
    Date.compare(due_date, Date.utc_today()) == :lt
  end

  defp overdue?(_), do: false

end
