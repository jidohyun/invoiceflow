defmodule AutoMyInvoice.Emails.OverdueEmail do
  @moduledoc "Swoosh email builder for overdue invoice notifications."

  import Swoosh.Email

  @from_name "AutoMyInvoice"

  @spec build(map()) :: Swoosh.Email.t()
  def build(%{invoice: invoice, client: client, from_email: from_email}) do
    due_date = Calendar.strftime(invoice.due_date, "%B %d, %Y")
    amount = format_amount(invoice.amount, invoice.currency)
    days_overdue = Date.diff(Date.utc_today(), invoice.due_date)
    payment_link = Map.get(invoice, :paddle_payment_link)

    assigns = %{
      client_name: client.name,
      invoice_number: invoice.invoice_number,
      amount: amount,
      due_date: due_date,
      days_overdue: days_overdue,
      payment_link: payment_link
    }

    {subject, html, text} = build_content(assigns)

    new()
    |> to({client.name, client.email})
    |> from({@from_name, from_email})
    |> subject(subject)
    |> html_body(html)
    |> text_body(text)
  end

  defp build_content(assigns) do
    subject = "연체 알림: 송장 #{assigns.invoice_number} — #{assigns.amount} 미납"

    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header" style="color:#c62828;">연체 알림 / Overdue Notice</div>
      <p>#{assigns.client_name}님께,</p>
      <p>송장 <strong>#{assigns.invoice_number}</strong>의 결제 기한이 <strong>#{assigns.days_overdue}일</strong> 경과하였습니다.
      아래 내역을 확인하시고 조속한 결제를 부탁드립니다.</p>
      <div class="details" style="border-left: 4px solid #c62828;">
        <div class="row"><span class="label">송장 번호</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">미납 금액</span><span class="amount" style="color:#c62828;">#{assigns.amount}</span></div>
        <div class="row"><span class="label">결제 기한</span><span>#{assigns.due_date}</span></div>
        <div class="row"><span class="label">연체 일수</span><span style="color:#c62828; font-weight:bold;">#{assigns.days_overdue}일</span></div>
      </div>
      <p>이미 결제를 완료하셨다면 이 알림을 무시해 주세요.
      결제에 어려움이 있으시면 회신하여 주시기 바랍니다.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>감사합니다.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    #{assigns.client_name}님께,

    송장 #{assigns.invoice_number}의 결제 기한이 #{assigns.days_overdue}일 경과하였습니다.

    송장 번호: #{assigns.invoice_number}
    미납 금액: #{assigns.amount}
    결제 기한: #{assigns.due_date}
    연체 일수: #{assigns.days_overdue}일

    이미 결제를 완료하셨다면 이 알림을 무시해 주세요.
    결제에 어려움이 있으시면 회신하여 주시기 바랍니다.
    #{pay_now_text(assigns.payment_link)}
    감사합니다.

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  defp styles do
    """
    <style>
      body { font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 24px; }
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
      <a href="#{url}" style="display:inline-block;padding:12px 32px;background:#c62828;color:#fff;text-decoration:none;border-radius:6px;font-weight:600;font-size:16px;">
        지금 결제하기 / Pay Now
      </a>
    </div>
    """
  end

  defp pay_now_text(nil), do: ""
  defp pay_now_text(""), do: ""
  defp pay_now_text(url), do: "\n지금 결제하기: #{url}\n"

  defp footer do
    "<div class=\"footer\">이 알림은 AutoMyInvoice에서 발송되었습니다.</div>"
  end

  defp format_amount(%Decimal{} = amount, currency) do
    symbol = currency_symbol(currency)
    "#{symbol}#{Decimal.to_string(Decimal.round(amount, 2))}"
  end

  defp format_amount(amount, currency) when is_number(amount) do
    format_amount(Decimal.new(amount), currency)
  end

  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol("GBP"), do: "£"
  defp currency_symbol("JPY"), do: "¥"
  defp currency_symbol("KRW"), do: "₩"
  defp currency_symbol(code), do: "#{code} "
end
