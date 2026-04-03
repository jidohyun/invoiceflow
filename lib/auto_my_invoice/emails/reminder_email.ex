defmodule AutoMyInvoice.Emails.ReminderEmail do
  @moduledoc "Swoosh email builder for reminder notifications (3 steps with escalating tone)."

  import Swoosh.Email

  @from_name "AutoMyInvoice"

  @spec build(map()) :: Swoosh.Email.t()
  def build(%{reminder: reminder, invoice: invoice, client: client, from_email: from_email}) do
    due_date = Calendar.strftime(invoice.due_date, "%B %d, %Y")
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

    {subject, html, text} = content_for_step(reminder.step, %{
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

  # Step 0: Manual reminder (friendly tone, distinct subject)
  defp content_for_step(0, assigns) do
    subject = "Payment reminder: Invoice #{assigns.invoice_number}"

    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">Payment Reminder</div>
      <p>Hi #{assigns.client_name},</p>
      <p>This is a friendly reminder that invoice <strong>#{assigns.invoice_number}</strong> for
      <strong>#{assigns.amount}</strong> was due on <strong>#{assigns.due_date}</strong>.</p>
      <div class="details">
        <div class="row"><span class="label">Invoice</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">Amount Due</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">Due Date</span><span>#{assigns.due_date}</span></div>
      </div>
      <p>If you've already sent payment, please disregard this message. Otherwise, we'd appreciate
      payment at your earliest convenience.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>Thanks so much!</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    Hi #{assigns.client_name},

    This is a friendly reminder that invoice #{assigns.invoice_number} for #{assigns.amount} was due on #{assigns.due_date}.

    If you've already sent payment, please disregard this message.
    Otherwise, we'd appreciate payment at your earliest convenience.
    #{pay_now_text(assigns.payment_link)}
    Thanks so much!

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 1 (D+1): Friendly check-in
  defp content_for_step(1, assigns) do
    subject = "Friendly reminder: Invoice #{assigns.invoice_number} — #{assigns.amount}"

    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">Payment Reminder</div>
      <p>Hi #{assigns.client_name},</p>
      <p>Just a quick reminder that invoice <strong>#{assigns.invoice_number}</strong> for
      <strong>#{assigns.amount}</strong> was due on <strong>#{assigns.due_date}</strong>.</p>
      <div class="details">
        <div class="row"><span class="label">Invoice</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">Amount Due</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">Due Date</span><span>#{assigns.due_date}</span></div>
      </div>
      <p>If you've already sent payment, please disregard this message. Otherwise, we'd appreciate
      payment at your earliest convenience.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>Thanks so much!</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    Hi #{assigns.client_name},

    Just a quick reminder that invoice #{assigns.invoice_number} for #{assigns.amount} was due on #{assigns.due_date}.

    If you've already sent payment, please disregard this message.
    Otherwise, we'd appreciate payment at your earliest convenience.
    #{pay_now_text(assigns.payment_link)}
    Thanks so much!

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 2 (D+7): Gentle nudge
  defp content_for_step(2, assigns) do
    subject = "Follow-up: Invoice #{assigns.invoice_number} is #{assigns.days_overdue} days past due"

    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header">Payment Follow-Up</div>
      <p>Hi #{assigns.client_name},</p>
      <p>We wanted to follow up on invoice <strong>#{assigns.invoice_number}</strong> for
      <strong>#{assigns.amount}</strong>, which was due on #{assigns.due_date}.
      It is now <strong>#{assigns.days_overdue} days past due</strong>.</p>
      <div class="details">
        <div class="row"><span class="label">Invoice</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">Amount Due</span><span class="amount">#{assigns.amount}</span></div>
        <div class="row"><span class="label">Due Date</span><span>#{assigns.due_date}</span></div>
        <div class="row"><span class="label">Days Overdue</span><span style="color:#e65100;">#{assigns.days_overdue}</span></div>
      </div>
      <p>We understand things can get busy. Could you let us know when we can expect payment?
      If there are any issues, we're happy to discuss.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>Best regards</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    Hi #{assigns.client_name},

    We wanted to follow up on invoice #{assigns.invoice_number} for #{assigns.amount},
    which was due on #{assigns.due_date}. It is now #{assigns.days_overdue} days past due.

    Could you let us know when we can expect payment?
    If there are any issues, we're happy to discuss.
    #{pay_now_text(assigns.payment_link)}
    Best regards

    --
    AutoMyInvoice
    """

    {subject, html, text}
  end

  # Step 3 (D+14): Final notice
  defp content_for_step(3, assigns) do
    subject = "Final notice: Invoice #{assigns.invoice_number} — #{assigns.amount} overdue"

    html = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8" />#{styles()}</head>
    <body>
      <div class="header" style="color:#c62828;">Final Payment Notice</div>
      <p>Hi #{assigns.client_name},</p>
      <p>This is a final reminder regarding invoice <strong>#{assigns.invoice_number}</strong> for
      <strong>#{assigns.amount}</strong>. The payment is now <strong>#{assigns.days_overdue} days overdue</strong>.</p>
      <div class="details" style="border-left: 4px solid #c62828;">
        <div class="row"><span class="label">Invoice</span><span>#{assigns.invoice_number}</span></div>
        <div class="row"><span class="label">Amount Due</span><span class="amount" style="color:#c62828;">#{assigns.amount}</span></div>
        <div class="row"><span class="label">Original Due Date</span><span>#{assigns.due_date}</span></div>
        <div class="row"><span class="label">Days Overdue</span><span style="color:#c62828; font-weight:bold;">#{assigns.days_overdue}</span></div>
      </div>
      <p>Please arrange payment as soon as possible to avoid any further action.
      If you have questions or need to discuss payment arrangements, please reply to this email immediately.</p>
      #{pay_now_button(assigns.payment_link)}
      <p>Thank you for your prompt attention to this matter.</p>
      #{footer()}
    </body>
    </html>
    """

    text = """
    Hi #{assigns.client_name},

    FINAL NOTICE: Invoice #{assigns.invoice_number} for #{assigns.amount} is now #{assigns.days_overdue} days overdue.

    Please arrange payment as soon as possible.
    If you have questions or need to discuss payment arrangements,
    please reply to this email immediately.
    #{pay_now_text(assigns.payment_link)}
    Thank you for your prompt attention to this matter.

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
      <a href="#{url}" style="display:inline-block;padding:12px 32px;background:#7c3aed;color:#fff;text-decoration:none;border-radius:6px;font-weight:600;font-size:16px;">
        Pay Now
      </a>
    </div>
    """
  end

  defp pay_now_text(nil), do: ""
  defp pay_now_text(""), do: ""
  defp pay_now_text(url), do: "\nPay now: #{url}\n"

  defp footer do
    "<div class=\"footer\">This reminder was sent via AutoMyInvoice.</div>"
  end

  defp tracking_pixel("", _reminder_id), do: ""
  defp tracking_pixel(_base_url, nil), do: ""

  defp tracking_pixel(base_url, reminder_id) do
    ~s(<img src="#{base_url}/api/track/open/#{reminder_id}" width="1" height="1" alt="" style="display:none;" />)
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
