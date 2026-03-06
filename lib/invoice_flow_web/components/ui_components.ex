defmodule InvoiceFlowWeb.UiComponents do
  @moduledoc "Custom UI components for InvoiceFlow"
  use Phoenix.Component

  import InvoiceFlowWeb.CoreComponents, only: [icon: 1]


  # 1. stat_card - KPI dashboard card
  attr :title, :string, required: true
  attr :value, :string, required: true
  attr :change, :string, default: nil
  attr :change_type, :string, default: "neutral", values: ~w(up down neutral)
  attr :icon, :string, default: nil

  def stat_card(assigns) do
    ~H"""
    <div class="stat bg-base-100 rounded-box shadow">
      <div class="stat-figure text-primary">
        <.icon :if={@icon} name={@icon} class="size-8" />
      </div>
      <div class="stat-title">{@title}</div>
      <div class="stat-value text-primary">{@value}</div>
      <div :if={@change} class={"stat-desc #{change_color(@change_type)}"}>
        <span :if={@change_type == "up"}>↑</span>
        <span :if={@change_type == "down"}>↓</span>
        {@change}
      </div>
    </div>
    """
  end

  defp change_color("up"), do: "text-success"
  defp change_color("down"), do: "text-error"
  defp change_color(_), do: "text-base-content/60"

  # 2. status_badge - Invoice status with color mapping
  attr :status, :string, required: true

  def status_badge(assigns) do
    ~H"""
    <span class={"badge #{status_class(@status)}"}>{format_status(@status)}</span>
    """
  end

  defp status_class("draft"), do: "badge-ghost"
  defp status_class("sent"), do: "badge-info"
  defp status_class("overdue"), do: "badge-error"
  defp status_class("paid"), do: "badge-success"
  defp status_class("partially_paid"), do: "badge-warning"
  defp status_class("cancelled"), do: "badge-neutral"
  defp status_class(_), do: "badge-ghost"

  defp format_status(status) do
    status
    |> String.replace("_", " ")
    |> String.capitalize()
  end

  # 3. sidebar_link - Navigation link with active state
  attr :path, :string, required: true
  attr :current_path, :string, default: ""
  attr :icon, :string, required: true
  attr :label, :string, required: true

  def sidebar_link(assigns) do
    assigns =
      assign(
        assigns,
        :active,
        assigns.current_path == assigns.path ||
          (assigns.path != "/" && String.starts_with?(assigns.current_path, assigns.path))
      )

    ~H"""
    <li>
      <a href={@path} class={if @active, do: "active", else: ""}>
        <.icon name={@icon} class="size-5" />
        {@label}
      </a>
    </li>
    """
  end

  # 4. empty_state - No data placeholder
  attr :icon, :string, default: "hero-inbox"
  attr :title, :string, required: true
  attr :description, :string, default: nil
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class="flex flex-col items-center justify-center py-12 text-center">
      <.icon name={@icon} class="size-16 text-base-content/20 mb-4" />
      <h3 class="text-lg font-semibold text-base-content/70">{@title}</h3>
      <p :if={@description} class="text-sm text-base-content/50 mt-1 max-w-sm">{@description}</p>
      <div :if={@action != []} class="mt-4">
        {render_slot(@action)}
      </div>
    </div>
    """
  end

  # 5. page_header - Page title with actions
  attr :title, :string, required: true
  attr :subtitle, :string, default: nil
  slot :actions

  def page_header(assigns) do
    ~H"""
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
      <div>
        <h1 class="text-2xl font-bold">{@title}</h1>
        <p :if={@subtitle} class="text-sm text-base-content/60 mt-1">{@subtitle}</p>
      </div>
      <div :if={@actions != []} class="flex gap-2">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end

  # 6. money - Currency formatting
  attr :amount, :any, required: true
  attr :currency, :string, default: "USD"

  def money(assigns) do
    ~H"""
    <span class="font-mono">{format_money(@amount, @currency)}</span>
    """
  end

  @doc "Format a monetary amount with the given currency symbol."
  def format_money(nil, _currency), do: "-"

  def format_money(amount, currency) do
    float_amount =
      cond do
        is_struct(amount, Decimal) -> Decimal.to_float(amount)
        is_integer(amount) -> amount / 1.0
        is_float(amount) -> amount
        true -> 0.0
      end

    case currency do
      "USD" -> "$#{format_number(float_amount, 2)}"
      "EUR" -> "€#{format_number(float_amount, 2)}"
      "GBP" -> "£#{format_number(float_amount, 2)}"
      "KRW" -> "₩#{format_number(float_amount, 0)}"
      "JPY" -> "¥#{format_number(float_amount, 0)}"
      other -> "#{format_number(float_amount, 2)} #{other}"
    end
  end

  defp format_number(amount, decimals) do
    abs_amount = abs(amount)
    sign = if amount < 0, do: "-", else: ""

    formatted =
      :erlang.float_to_binary(abs_amount * 1.0, decimals: decimals)
      |> add_thousand_separators()

    sign <> formatted
  end

  defp add_thousand_separators(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        "#{insert_commas(int_part)}.#{dec_part}"

      [int_part] ->
        insert_commas(int_part)
    end
  end

  defp insert_commas(int_str) do
    int_str
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.map(&Enum.join/1)
    |> Enum.join(",")
    |> String.reverse()
  end

  # 7. date_display - Date formatting with relative time
  attr :date, :any, required: true
  attr :format, :string, default: "relative", values: ~w(relative short full)

  def date_display(assigns) do
    ~H"""
    <span title={format_date_full(@date)}>{format_date(@date, @format)}</span>
    """
  end

  defp format_date(nil, _), do: "-"
  defp format_date(date, "relative"), do: relative_time(date)
  defp format_date(date, "short"), do: format_date_short(date)
  defp format_date(date, "full"), do: format_date_full(date)
  defp format_date(date, _), do: format_date_short(date)

  defp format_date_short(nil), do: "-"
  defp format_date_short(%Date{} = date), do: Calendar.strftime(date, "%b %d, %Y")
  defp format_date_short(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")
  defp format_date_short(%DateTime{} = dt), do: Calendar.strftime(dt, "%b %d, %Y")

  defp format_date_full(nil), do: ""
  defp format_date_full(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date_full(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  defp format_date_full(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  defp relative_time(nil), do: "-"

  defp relative_time(%Date{} = date) do
    days = Date.diff(date, Date.utc_today())

    cond do
      days == 0 -> "Today"
      days == 1 -> "Tomorrow"
      days == -1 -> "Yesterday"
      days > 1 -> "In #{days} days"
      days < -1 -> "#{abs(days)} days ago"
    end
  end

  defp relative_time(%NaiveDateTime{} = dt), do: relative_time(NaiveDateTime.to_date(dt))
  defp relative_time(%DateTime{} = dt), do: relative_time(DateTime.to_date(dt))

  # 8. timeline - Vertical timeline for events
  attr :class, :string, default: ""

  slot :item, required: true do
    attr :title, :string, required: true
    attr :description, :string
    attr :status, :string
    attr :datetime, :string
  end

  def timeline(assigns) do
    ~H"""
    <ul class={"timeline timeline-vertical #{@class}"}>
      <li :for={item <- @item}>
        <div class="timeline-start text-sm text-base-content/60">{item[:datetime]}</div>
        <div class={"timeline-middle #{timeline_dot_class(item[:status])}"}>
          <.icon name={timeline_icon(item[:status])} class="size-4" />
        </div>
        <div class="timeline-end timeline-box">
          <div class="font-medium">{item[:title]}</div>
          <div :if={item[:description]} class="text-sm text-base-content/60">
            {item[:description]}
          </div>
        </div>
        <hr />
      </li>
    </ul>
    """
  end

  defp timeline_dot_class("completed"), do: "text-success"
  defp timeline_dot_class("active"), do: "text-primary"
  defp timeline_dot_class("pending"), do: "text-base-content/30"
  defp timeline_dot_class(_), do: "text-base-content/30"

  defp timeline_icon("completed"), do: "hero-check-circle-mini"
  defp timeline_icon("active"), do: "hero-play-circle-mini"
  defp timeline_icon(_), do: "hero-clock-mini"

  # 9. upload_zone - Drag and drop file upload area
  attr :upload, :any, default: nil
  attr :accepted, :string, default: "PDF, JPG, PNG"
  attr :max_size, :string, default: "10MB"

  def upload_zone(assigns) do
    ~H"""
    <div
      class="border-2 border-dashed border-base-300 rounded-box p-8 text-center hover:border-primary/50 transition-colors"
      phx-drop-target={@upload && @upload.ref}
    >
      <.icon name="hero-cloud-arrow-up" class="size-12 text-base-content/30 mx-auto mb-4" />
      <p class="text-lg font-medium">Drop files here or click to upload</p>
      <p class="text-sm text-base-content/60 mt-1">Accepted: {@accepted} (max {@max_size})</p>
      <%= if @upload do %>
        <label class="btn btn-primary btn-sm mt-4 cursor-pointer">
          Browse Files
          <.live_file_input upload={@upload} class="hidden" />
        </label>
      <% end %>
    </div>
    """
  end

  # 10. plan_badge - User plan display
  attr :plan, :string, required: true

  def plan_badge(assigns) do
    ~H"""
    <span class={"badge #{plan_class(@plan)}"}>{String.capitalize(@plan)}</span>
    """
  end

  defp plan_class("free"), do: "badge-ghost"
  defp plan_class("starter"), do: "badge-primary"
  defp plan_class("pro"), do: "badge-accent"
  defp plan_class(_), do: "badge-ghost"
end
