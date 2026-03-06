defmodule InvoiceFlow.Emails.InvoiceEmail do
  @moduledoc "Swoosh email builder for invoice notifications."

  import Swoosh.Email

  @from_name "InvoiceFlow"

  @spec invoice_sent(map()) :: Swoosh.Email.t()
  def invoice_sent(%{invoice: invoice, client: client, from_email: from_email}) do
    due_date = Calendar.strftime(invoice.due_date, "%B %d, %Y")
    amount = format_amount(invoice.amount, invoice.currency)

    new()
    |> to({client.name, client.email})
    |> from({@from_name, from_email})
    |> subject("Invoice #{invoice.invoice_number} — #{amount} due #{due_date}")
    |> html_body(html_body(invoice, client, due_date, amount))
    |> text_body(text_body(invoice, client, due_date, amount))
  end

  defp html_body(invoice, client, due_date, amount) do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="UTF-8" />
      <style>
        body { font-family: Arial, sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 24px; }
        .header { font-size: 22px; font-weight: bold; margin-bottom: 16px; }
        .details { background: #f9f9f9; border-radius: 6px; padding: 16px; margin: 16px 0; }
        .row { display: flex; justify-content: space-between; margin-bottom: 8px; }
        .label { color: #666; }
        .amount { font-size: 28px; font-weight: bold; color: #111; margin: 8px 0; }
        .footer { margin-top: 32px; color: #888; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="header">Invoice #{invoice.invoice_number}</div>
      <p>Hi #{client.name},</p>
      <p>Please find your invoice details below. Payment is due by <strong>#{due_date}</strong>.</p>
      <div class="details">
        <div class="row"><span class="label">Invoice Number</span><span>#{invoice.invoice_number}</span></div>
        <div class="row"><span class="label">Due Date</span><span>#{due_date}</span></div>
        <div class="row"><span class="label">Amount Due</span><span class="amount">#{amount}</span></div>
      </div>
      #{if invoice.notes, do: "<p><strong>Notes:</strong> #{invoice.notes}</p>", else: ""}
      <p>Please process payment at your earliest convenience. If you have any questions, reply to this email.</p>
      <div class="footer">This invoice was sent via InvoiceFlow.</div>
    </body>
    </html>
    """
  end

  defp text_body(invoice, client, due_date, amount) do
    notes_section =
      if invoice.notes, do: "\nNotes: #{invoice.notes}\n", else: ""

    """
    Invoice #{invoice.invoice_number}

    Hi #{client.name},

    Please find your invoice details below.

    Invoice Number: #{invoice.invoice_number}
    Amount Due:     #{amount}
    Due Date:       #{due_date}
    #{notes_section}
    Please process payment at your earliest convenience.
    If you have any questions, reply to this email.

    --
    InvoiceFlow
    """
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
