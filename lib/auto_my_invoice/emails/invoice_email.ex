defmodule AutoMyInvoice.Emails.InvoiceEmail do
  @moduledoc "Swoosh email builder for invoice notifications."

  import Swoosh.Email

  @from_name "AutoMyInvoice"

  @spec invoice_sent(map()) :: Swoosh.Email.t()
  def invoice_sent(%{invoice: invoice, client: client, from_email: from_email}) do
    due_date = format_date(invoice.due_date)
    amount = format_amount(invoice.amount, invoice.currency)

    new()
    |> to({client.name, client.email})
    |> from({@from_name, from_email})
    |> subject("[송장 #{invoice.invoice_number}] #{amount} · 기한 #{due_date}")
    |> html_body(html_body(invoice, client, due_date, amount))
    |> text_body(text_body(invoice, client, due_date, amount))
  end

  defp html_body(invoice, client, due_date, amount) do
    """
    <!DOCTYPE html>
    <html lang="ko">
    <head>
      <meta charset="UTF-8" />
      <style>
        body { font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", sans-serif; color: #333; max-width: 600px; margin: 0 auto; padding: 24px; }
        .header { font-size: 22px; font-weight: bold; margin-bottom: 16px; }
        .details { background: #f9f9f9; border-radius: 6px; padding: 16px; margin: 16px 0; }
        .row { display: flex; justify-content: space-between; margin-bottom: 8px; }
        .label { color: #666; }
        .amount { font-size: 28px; font-weight: bold; color: #111; margin: 8px 0; }
        .footer { margin-top: 32px; color: #888; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="header">송장 #{invoice.invoice_number}</div>
      <p>#{client.name} 담당자님께,</p>
      <p>아래 내용으로 송장을 보내드립니다. 지급 기한은 <strong>#{due_date}</strong>입니다.</p>
      <div class="details">
        <div class="row"><span class="label">송장 번호</span><span>#{invoice.invoice_number}</span></div>
        <div class="row"><span class="label">지급 기한</span><span>#{due_date}</span></div>
        <div class="row"><span class="label">청구 금액</span><span class="amount">#{amount}</span></div>
      </div>
      #{if invoice.notes, do: "<p><strong>메모:</strong> #{invoice.notes}</p>", else: ""}
      <p>기한 내 결제 부탁드립니다. 문의사항은 이 이메일에 답장해 주세요.</p>
      <div class="footer">본 송장은 AutoMyInvoice를 통해 발송되었습니다.</div>
    </body>
    </html>
    """
  end

  defp text_body(invoice, client, due_date, amount) do
    notes_section =
      if invoice.notes, do: "\n메모: #{invoice.notes}\n", else: ""

    """
    송장 #{invoice.invoice_number}

    #{client.name} 담당자님께,

    아래 내용으로 송장을 보내드립니다.

    송장 번호: #{invoice.invoice_number}
    청구 금액: #{amount}
    지급 기한: #{due_date}
    #{notes_section}
    기한 내 결제 부탁드립니다.
    문의사항은 이 이메일에 답장해 주세요.

    --
    AutoMyInvoice
    """
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
