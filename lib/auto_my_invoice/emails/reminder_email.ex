defmodule AutoMyInvoice.Emails.ReminderEmail do
  @moduledoc "Swoosh email builder for reminder notifications (3 steps with escalating tone)."

  import Swoosh.Email

  @from_name "AutoMyInvoice"

  @spec build(map()) :: Swoosh.Email.t()
  def build(%{reminder: reminder, invoice: invoice, client: client, from_email: from_email}) do
    due_date = format_date(invoice.due_date)
    amount = format_amount(invoice.amount, invoice.currency)
    days_overdue = Date.diff(Date.utc_today(), invoice.due_date)
    payment_link = Map.get(invoice, :paddle_payment_link)
    base_url = Map.get(reminder, :tracking_base_url, "")
    reminder_id = Map.get(reminder, :id)

    tracked_payment_link =
      if payment_link && reminder_id && base_url != "" do
        "#{base_url}/api/track/click/#{reminder_id}"
      else
        payment_link
      end

    {subject, html, text} =
      content_for_step(reminder.step, %{
        client_name: client.name,
        invoice_number: invoice.invoice_number,
        amount: amount,
        due_date: due_date,
        days_overdue: days_overdue,
        payment_link: tracked_payment_link
      })

    html = html <> tracking_pixel(base_url, reminder_id)

    new()
    |> to({client.name, client.email})
    |> from({@from_name, from_email})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  # Step 0: 수동 리마인더 (친근한 톤)
  defp content_for_step(0, assigns) do
    subject = "결제 안내: 송장 #{assigns.invoice_number}"

    html = """
    <!DOCTYPE html>
    <html lang="ko">
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">결제 안내</div>
      <p>#{assigns.client_name} 담당자님께,</p>
      <p>송장 <strong>#{assigns.invoice_number}</strong> (<strong>#{assigns.amount}</strong>)의
      지급 기한이 <strong>#{assigns.due_date}</strong>이었음을 알려드립니다.</p>
      <div class="details">
        <div class="row"><span class="label">송장</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">청구 금액</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">지급 기한</span><span>#{assigns.due_date}</span></div>
      </div>
      <p>이미 결제를 완료하셨다면 이 메일은 무시해 주셔도 됩니다. 그렇지 않다면
      빠른 시일 내에 결제 부탁드립니다.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>감사합니다.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    #{assigns.client_name} 담당자님께,

    송장 #{assigns.invoice_number} (#{assigns.amount})의 지급 기한이 #{assigns.due_date}이었음을 알려드립니다.

    이미 결제를 완료하셨다면 이 메일은 무시해 주셔도 됩니다.
    그렇지 않다면 빠른 시일 내에 결제 부탁드립니다.
    #{pay_now_text(assigns.payment_link)}
    감사합니다.

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 1 (D+1): 친근한 확인
  defp content_for_step(1, assigns) do
    subject = "송장 #{assigns.invoice_number} 결제 안내 · #{assigns.amount}"

    html = """
    <!DOCTYPE html>
    <html lang="ko">
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">결제 안내</div>
      <p>#{assigns.client_name} 담당자님께,</p>
      <p>송장 <strong>#{assigns.invoice_number}</strong> (<strong>#{assigns.amount}</strong>)의
      지급 기한이 <strong>#{assigns.due_date}</strong>이었습니다.</p>
      <div class="details">
        <div class="row"><span class="label">송장</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">청구 금액</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">지급 기한</span><span>#{assigns.due_date}</span></div>
      </div>
      <p>이미 결제하셨다면 이 메일은 무시해 주세요. 아직이시라면 편하실 때 결제 부탁드립니다.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>감사합니다.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    #{assigns.client_name} 담당자님께,

    송장 #{assigns.invoice_number} (#{assigns.amount})의 지급 기한이 #{assigns.due_date}이었습니다.

    이미 결제하셨다면 이 메일은 무시해 주세요.
    아직이시라면 편하실 때 결제 부탁드립니다.
    #{pay_now_text(assigns.payment_link)}
    감사합니다.

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 2 (D+7): 추가 확인
  defp content_for_step(2, assigns) do
    subject = "[확인 요청] 송장 #{assigns.invoice_number} · #{assigns.days_overdue}일 연체"

    html = """
    <!DOCTYPE html>
    <html lang="ko">
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">결제 확인 요청</div>
      <p>#{assigns.client_name} 담당자님께,</p>
      <p>송장 <strong>#{assigns.invoice_number}</strong> (<strong>#{assigns.amount}</strong>)
      건에 대해 확인 부탁드립니다. 지급 기한은 #{assigns.due_date}이었고,
      현재 <strong>#{assigns.days_overdue}일 경과</strong>한 상태입니다.</p>
      <div class="details">
        <div class="row"><span class="label">송장</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">청구 금액</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">지급 기한</span><span>#{assigns.due_date}</span></div>
        <div class="row"><span class="label">경과일</span><span style="color:#e65100;">#{assigns.days_overdue}일</span></div>
      </div>
      <p>바쁘신 상황은 충분히 이해합니다. 언제쯤 결제가 가능하실지 알려주실 수 있을까요?
      협의가 필요한 사항이 있다면 언제든지 회신 주세요.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>감사합니다.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    #{assigns.client_name} 담당자님께,

    송장 #{assigns.invoice_number} (#{assigns.amount}) 건에 대해 확인 부탁드립니다.
    지급 기한 #{assigns.due_date}에서 #{assigns.days_overdue}일 경과한 상태입니다.

    언제쯤 결제가 가능하실지 알려주실 수 있을까요?
    협의가 필요한 사항이 있다면 언제든지 회신 주세요.
    #{pay_now_text(assigns.payment_link)}
    감사합니다.

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 3 (D+14): 최종 통보
  defp content_for_step(3, assigns) do
    subject = "[최종 통보] 송장 #{assigns.invoice_number} · #{assigns.amount} 연체"

    html = """
    <!DOCTYPE html>
    <html lang="ko">
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header" style="color:#c62828;">결제 최종 통보</div>
      <p>#{assigns.client_name} 담당자님께,</p>
      <p>송장 <strong>#{assigns.invoice_number}</strong> (<strong>#{assigns.amount}</strong>)
      건에 대한 최종 안내입니다. 현재 <strong>#{assigns.days_overdue}일 연체</strong> 상태입니다.</p>
      <div class="details" style="border-left: 4px solid #c62828;">
        <div class="row"><span class="label">송장</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">청구 금액</span><span class="amount" style="color:#c62828;">#{assigns.amount}</span></div>
        <div class="row"><span class="label">지급 기한</span><span>#{assigns.due_date}</span></div>
        <div class="row"><span class="label">경과일</span><span style="color:#c62828; font-weight:bold;">#{assigns.days_overdue}일</span></div>
      </div>
      <p>추가 조치를 피하기 위해 가능한 한 빨리 결제를 진행해 주시기 바랍니다.
      협의가 필요하시면 즉시 이 메일에 회신 부탁드립니다.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>신속한 조치 감사드립니다.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    #{assigns.client_name} 담당자님께,

    [최종 통보] 송장 #{assigns.invoice_number} (#{assigns.amount}) 건이 #{assigns.days_overdue}일 연체 중입니다.

    추가 조치를 피하기 위해 가능한 한 빨리 결제를 진행해 주시기 바랍니다.
    협의가 필요하시면 즉시 이 메일에 회신 부탁드립니다.
    #{pay_now_text(assigns.payment_link)}
    신속한 조치 감사드립니다.

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Fallback for unknown steps
  defp content_for_step(_step, assigns), do: content_for_step(1, assigns)

  defp styles do
    """
    <style>
      body { font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 24px; }
      .header { font-size: 22px; font-weight: bold; margin-bottom: 16px; }
      .details { background: #f9f9f9; border-radius: 6px; padding: 16px; margin: 16px 0; }
      .row { display: flex; justify-content: space-between; margin-bottom: 8px; }
      .label { color: #666; }
      .amount { font-size: 28px; font-weight: bold; color: #111; margin: 8px 0; }
      .footer { margin-top: 32px; color: #888; font-size: 12px; }
    </style>
    """
  end

  defp pay_now_button(nil), do: ""
  defp pay_now_button(""), do: ""

  defp pay_now_button(url) do
    """
    <div style="text-align:center;margin:24px 0;">
      <a href="#{url}" style="display:inline-block;padding:12px 32px;background:#7c3aed;color:#fff;text-decoration:none;border-radius:6px;font-weight:600;font-size:16px;">
        바로 결제하기
      </a>
    </div>
    """
  end

  defp pay_now_text(nil), do: ""
  defp pay_now_text(""), do: ""
  defp pay_now_text(url), do: "\n바로 결제: #{url}\n"

  defp footer do
    "<div class=\"footer\">본 안내는 AutoMyInvoice를 통해 발송되었습니다.</div>"
  end

  defp tracking_pixel("", _reminder_id), do: ""
  defp tracking_pixel(_base_url, nil), do: ""

  defp tracking_pixel(base_url, reminder_id) do
    ~s(<img src="#{base_url}/api/track/open/#{reminder_id}" width="1" height="1" alt="" style="display:none;" />)
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y년 %m월 %d일")
  defp format_date(other), do: to_string(other)

  defp format_amount(%Decimal{} = amount, "KRW") do
    "₩#{format_integer(amount)}"
  end

  defp format_amount(%Decimal{} = amount, currency) do
    symbol = currency_symbol(currency)
    "#{symbol}#{Decimal.to_string(Decimal.round(amount, 2))}"
  end

  defp format_amount(amount, currency) when is_number(amount) do
    format_amount(Decimal.new(amount), currency)
  end

  defp format_integer(%Decimal{} = amount) do
    amount
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> Integer.to_string()
    |> add_thousand_separator()
  end

  defp add_thousand_separator(str) do
    sign = if String.starts_with?(str, "-"), do: "-", else: ""
    digits = String.replace_leading(str, "-", "")

    formatted =
      digits
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map(&Enum.join/1)
      |> Enum.join(",")
      |> String.reverse()

    sign <> formatted
  end

  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol("GBP"), do: "£"
  defp currency_symbol("JPY"), do: "¥"
  defp currency_symbol("KRW"), do: "₩"
  defp currency_symbol(code), do: "#{code} "
end
