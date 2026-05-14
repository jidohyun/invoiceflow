defmodule AutoMyInvoiceWeb.InvoiceLive.Index do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Invoices, PubSubTopics}

  @statuses [
    {"전체", nil},
    {"임시저장", "draft"},
    {"발송", "sent"},
    {"연체", "overdue"},
    {"결제완료", "paid"}
  ]

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user

    if connected?(socket) do
      Phoenix.PubSub.subscribe(AutoMyInvoice.PubSub, PubSubTopics.user_invoices(user.id))
    end

    {:ok,
     socket
     |> assign(:page_title, "송장")
     |> assign(:statuses, @statuses)
     |> assign(:sort_by, :due_date)
     |> assign(:sort_order, :desc)
     |> load_counts()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    status = parse_status(params["status"])
    search = params["q"] || ""

    {:noreply,
     socket
     |> assign(:current_status, status)
     |> assign(:search, search)
     |> load_invoices(status, search)}
  end

  @impl true
  def handle_event("search", %{"q" => search}, socket) do
    params = build_params(socket.assigns.current_status, search)
    {:noreply, push_patch(socket, to: ~p"/invoices?#{params}")}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    field = String.to_existing_atom(field)

    {sort_by, sort_order} =
      if socket.assigns.sort_by == field do
        {field, toggle_order(socket.assigns.sort_order)}
      else
        {field, :asc}
      end

    {:noreply,
     socket
     |> assign(:sort_by, sort_by)
     |> assign(:sort_order, sort_order)
     |> load_invoices(socket.assigns.current_status, socket.assigns.search)}
  end

  @impl true
  def handle_info({:invoice_updated, _invoice}, socket) do
    {:noreply,
     socket
     |> load_counts()
     |> load_invoices(socket.assigns.current_status, socket.assigns.search)}
  end

  ## Private

  defp load_invoices(socket, status, search) do
    user = socket.assigns.current_user

    opts =
      [sort_by: socket.assigns.sort_by, sort_order: socket.assigns.sort_order]
      |> maybe_add(:status, status)
      |> maybe_add(:search, normalize_search(search))

    assign(socket, :invoices, Invoices.list_invoices(user.id, opts))
  end

  defp load_counts(socket) do
    counts = Invoices.count_by_status(socket.assigns.current_user.id)
    assign(socket, :status_counts, counts)
  end

  defp parse_status(nil), do: nil
  defp parse_status(""), do: nil
  defp parse_status(s) when s in ~w(draft sent overdue paid), do: s
  defp parse_status(_), do: nil

  defp normalize_search(s) when is_binary(s) and s != "", do: String.trim(s)
  defp normalize_search(_), do: nil

  defp build_params(status, search) do
    %{}
    |> maybe_put("status", status)
    |> maybe_put("q", if(search != "", do: search, else: nil))
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp maybe_add(opts, _key, nil), do: opts
  defp maybe_add(opts, key, value), do: Keyword.put(opts, key, value)

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc

  defp sort_indicator(assigns, field) do
    if assigns.sort_by == field do
      if assigns.sort_order == :asc, do: " ↑", else: " ↓"
    else
      ""
    end
  end

  defp tab_count(counts, nil), do: Map.get(counts, "all", 0)
  defp tab_count(counts, status), do: Map.get(counts, status, 0)

  defp empty_state_description(nil, ""), do: "첫 송장을 발행해 시작해 보세요."
  defp empty_state_description(nil, _q), do: "검색 조건에 맞는 송장이 없습니다."
  defp empty_state_description(status, ""), do: "#{status_label(status)} 송장이 없습니다."
  defp empty_state_description(status, _q), do: "검색 조건에 맞는 #{status_label(status)} 송장이 없습니다."

  defp status_label("draft"), do: "임시저장"
  defp status_label("sent"), do: "발송"
  defp status_label("overdue"), do: "연체"
  defp status_label("paid"), do: "결제완료"
  defp status_label(other), do: other

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="송장">
      <:actions>
        <.link navigate={~p"/invoices/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> 새 송장
        </.link>
      </:actions>
    </.page_header>

    <div class="flex flex-col sm:flex-row gap-4 mb-6">
      <div role="tablist" class="tabs tabs-boxed">
        <.link
          :for={{label, status} <- @statuses}
          role="tab"
          class={"tab #{if @current_status == status, do: "tab-active"}"}
          patch={~p"/invoices?#{build_params(status, @search)}"}
        >
          {label}
          <span class="ml-1 badge badge-sm">{tab_count(@status_counts, status)}</span>
        </.link>
      </div>

      <form phx-change="search" phx-submit="search" class="flex-1">
        <input
          type="text"
          name="q"
          value={@search}
          placeholder="송장 번호, 거래처, 메모로 검색..."
          class="input input-bordered input-sm w-full max-w-xs"
          phx-debounce="300"
        />
      </form>
    </div>

    <%= if @invoices == [] do %>
      <.empty_state
        title="송장이 없습니다"
        description={empty_state_description(@current_status, @search)}
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
        <table class="table">
          <thead>
            <tr>
              <th>송장 번호</th>
              <th>거래처</th>
              <th class="cursor-pointer" phx-click="sort" phx-value-field="amount">
                금액{sort_indicator(assigns, :amount)}
              </th>
              <th>상태</th>
              <th class="cursor-pointer" phx-click="sort" phx-value-field="due_date">
                지급 기한{sort_indicator(assigns, :due_date)}
              </th>
              <th class="cursor-pointer" phx-click="sort" phx-value-field="inserted_at">
                작성일{sort_indicator(assigns, :inserted_at)}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              :for={invoice <- @invoices}
              class="hover cursor-pointer"
              phx-click={JS.navigate(~p"/invoices/#{invoice.id}")}
            >
              <td class="font-mono text-sm">{invoice.invoice_number}</td>
              <td>{if(invoice.client, do: invoice.client.name, else: "-")}</td>
              <td><.money amount={invoice.amount} currency={invoice.currency} /></td>
              <td><.status_badge status={invoice.status} /></td>
              <td><.date_display date={invoice.due_date} /></td>
              <td><.date_display date={invoice.inserted_at} format="short" /></td>
            </tr>
          </tbody>
        </table>
      </div>
    <% end %>
    """
  end
end
