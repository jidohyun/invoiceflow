defmodule AutoMyInvoice.PDF.InvoicePDF do
  @moduledoc "Generates PDF for an invoice using ChromicPDF."

  @spec generate(map()) :: {:ok, binary()} | {:error, String.t()}
  def generate(%{invoice: invoice, client: client}) do
    html = render_html(invoice, client)

    case ChromicPDF.print_to_pdf({:html, html}, print_params()) do
      {:ok, blob} -> {:ok, blob}
      {:error, reason} -> {:error, "PDF generation failed: #{inspect(reason)}"}
    end
  end

  defp print_params do
    [
      print_to_pdf: %{
        marginTop: 0.5,
        marginBottom: 0.5,
        marginLeft: 0.5,
        marginRight: 0.5,
        printBackground: true
      }
    ]
  end

  defp render_html(invoice, client) do
    due_date = if invoice.due_date, do: format_date(invoice.due_date), else: "-"
    amount = format_amount(invoice.amount, invoice.currency)
    items_html = render_items(invoice.items || [], invoice.currency)

    sent_row =
      if invoice.sent_at do
        "<tr><td style='color:#666;padding:4px 12px 4px 0;'>발송일</td><td style='padding:4px 0;'>#{format_date(invoice.sent_at)}</td></tr>"
      else
        ""
      end

    paid_row =
      if invoice.paid_at do
        "<tr><td style='color:#666;padding:4px 12px 4px 0;'>결제일</td><td style='padding:4px 0;'>#{format_date(invoice.paid_at)}</td></tr>"
      else
        ""
      end

    notes_section =
      if invoice.notes && invoice.notes != "" do
        "<div style='margin-top:24px;'><h3 style='font-size:14px;color:#666;margin-bottom:8px;'>메모</h3><p style='white-space:pre-wrap;'>#{escape_html(invoice.notes)}</p></div>"
      else
        ""
      end

    """
    <!DOCTYPE html>
    <html lang="ko">
    <head>
      <meta charset="UTF-8" />
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Malgun Gothic", "Apple SD Gothic Neo", sans-serif; color: #333; padding: 40px; font-size: 14px; line-height: 1.5; }
        .header { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 40px; }
        .brand { font-size: 24px; font-weight: 700; color: #7c3aed; }
        .invoice-title { font-size: 28px; font-weight: 700; color: #111; text-align: right; }
        .invoice-number { font-size: 14px; color: #666; text-align: right; }
        .status { display: inline-block; padding: 4px 12px; border-radius: 12px; font-size: 12px; font-weight: 600; }
        .status-draft { background: #f3f4f6; color: #6b7280; }
        .status-sent { background: #dbeafe; color: #2563eb; }
        .status-paid { background: #d1fae5; color: #059669; }
        .status-overdue { background: #fee2e2; color: #dc2626; }
        .status-partially_paid { background: #fef3c7; color: #b45309; }
        .status-cancelled { background: #f3f4f6; color: #6b7280; }
        .details { display: flex; justify-content: space-between; margin-bottom: 32px; }
        .details-block { }
        .details-block h3 { font-size: 12px; color: #666; letter-spacing: 0.5px; margin-bottom: 8px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 24px; }
        th { background: #f9fafb; text-align: left; padding: 10px 12px; font-size: 12px; color: #666; letter-spacing: 0.5px; border-bottom: 2px solid #e5e7eb; }
        td { padding: 10px 12px; border-bottom: 1px solid #f3f4f6; }
        .text-right { text-align: right; }
        .total-row { font-weight: 700; font-size: 16px; border-top: 2px solid #333; }
        .total-row td { padding-top: 12px; }
        .footer { margin-top: 40px; padding-top: 16px; border-top: 1px solid #e5e7eb; color: #999; font-size: 11px; text-align: center; }
      </style>
    </head>
    <body>
      <div class="header">
        <div>
          <div class="brand">AutoMyInvoice</div>
        </div>
        <div>
          <div class="invoice-title">송장 / INVOICE</div>
          <div class="invoice-number">#{escape_html(invoice.invoice_number)}</div>
          <div style="text-align:right;margin-top:8px;">
            <span class="status status-#{invoice.status}">#{status_label(invoice.status)}</span>
          </div>
        </div>
      </div>

      <div class="details">
        <div class="details-block">
          <h3>공급받는자</h3>
          <p><strong>#{escape_html(client.name)}</strong></p>
          <p>#{escape_html(client.email)}</p>
          #{if client.company, do: "<p>#{escape_html(client.company)}</p>", else: ""}
        </div>
        <div class="details-block">
          <table style="width:auto;margin-bottom:0;">
            <tr><td style="color:#666;padding:4px 12px 4px 0;">지급 기한</td><td style="padding:4px 0;font-weight:600;">#{due_date}</td></tr>
            <tr><td style="color:#666;padding:4px 12px 4px 0;">청구 금액</td><td style="padding:4px 0;font-weight:600;font-size:18px;">#{amount}</td></tr>
            #{sent_row}
            #{paid_row}
          </table>
        </div>
      </div>

      #{items_html}
      #{notes_section}

      <div class="footer">
        AutoMyInvoice 발행 &bull; #{format_date(DateTime.utc_now())}
      </div>
    </body>
    </html>
    """
  end

  defp render_items([], _currency) do
    ""
  end

  defp render_items(items, currency) do
    rows =
      Enum.map(items, fn item ->
        """
        <tr>
          <td>#{escape_html(item.description || "")}</td>
          <td class="text-right">#{item.quantity}</td>
          <td class="text-right">#{format_amount(item.unit_price, currency)}</td>
          <td class="text-right">#{format_amount(item.total, currency)}</td>
        </tr>
        """
      end)
      |> Enum.join("")

    """
    <table>
      <thead>
        <tr>
          <th>품목</th>
          <th class="text-right">수량</th>
          <th class="text-right">단가</th>
          <th class="text-right">합계</th>
        </tr>
      </thead>
      <tbody>
        #{rows}
        <tr class="total-row">
          <td colspan="3" class="text-right">총액</td>
          <td class="text-right">#{format_amount(Enum.reduce(items, Decimal.new(0), fn i, acc -> Decimal.add(acc, i.total || Decimal.new(0)) end), currency)}</td>
        </tr>
      </tbody>
    </table>
    """
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y년 %m월 %d일")
  defp format_date(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y년 %m월 %d일")
  defp format_date(%NaiveDateTime{} = dt), do: Calendar.strftime(dt, "%Y년 %m월 %d일")
  defp format_date(other), do: to_string(other)

  defp format_amount(nil, _currency), do: "-"

  defp format_amount(%Decimal{} = amount, "KRW") do
    "₩#{format_integer(amount)}"
  end

  defp format_amount(%Decimal{} = amount, currency) do
    "#{currency_symbol(currency)}#{Decimal.round(amount, 2) |> Decimal.to_string(:normal)}"
  end

  defp format_amount(amount, currency) when is_number(amount) do
    format_amount(Decimal.new("#{amount}"), currency)
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

  defp status_label("draft"), do: "임시저장"
  defp status_label("sent"), do: "발송"
  defp status_label("overdue"), do: "연체"
  defp status_label("paid"), do: "결제완료"
  defp status_label("partially_paid"), do: "부분결제"
  defp status_label("cancelled"), do: "취소"
  defp status_label(other), do: other

  defp escape_html(nil), do: ""

  defp escape_html(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
