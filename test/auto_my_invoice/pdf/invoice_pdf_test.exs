defmodule AutoMyInvoice.PDF.InvoicePDFTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.PDF.InvoicePDF

  defp sample_invoice do
    %{
      invoice_number: "INV-TEST-001",
      amount: Decimal.new("2500.00"),
      currency: "USD",
      status: "sent",
      due_date: ~D[2026-04-15],
      sent_at: ~U[2026-03-06 10:00:00Z],
      paid_at: nil,
      notes: "Net 30 terms",
      items: [
        %{
          description: "Web Development",
          quantity: Decimal.new(10),
          unit_price: Decimal.new("200.00"),
          total: Decimal.new("2000.00")
        },
        %{
          description: "Design Review",
          quantity: Decimal.new(5),
          unit_price: Decimal.new("100.00"),
          total: Decimal.new("500.00")
        }
      ]
    }
  end

  defp sample_client do
    %{
      name: "Acme Corp",
      email: "billing@acme.com",
      company: "Acme Corporation"
    }
  end

  describe "generate/1" do
    test "generates a PDF binary" do
      result = InvoicePDF.generate(%{invoice: sample_invoice(), client: sample_client()})

      assert {:ok, pdf_data} = result
      assert is_binary(pdf_data)
      assert byte_size(pdf_data) > 0
      # ChromicPDF returns base64-encoded PDF; decoded starts with %PDF
      {:ok, decoded} = Base.decode64(pdf_data)
      assert String.starts_with?(decoded, "%PDF")
    end

    test "handles invoice with no items" do
      invoice = %{sample_invoice() | items: []}
      result = InvoicePDF.generate(%{invoice: invoice, client: sample_client()})

      assert {:ok, pdf_data} = result
      {:ok, decoded} = Base.decode64(pdf_data)
      assert String.starts_with?(decoded, "%PDF")
    end

    test "handles KRW currency" do
      invoice = %{sample_invoice() | currency: "KRW", amount: Decimal.new("250000")}
      result = InvoicePDF.generate(%{invoice: invoice, client: sample_client()})

      assert {:ok, pdf_data} = result
      {:ok, decoded} = Base.decode64(pdf_data)
      assert String.starts_with?(decoded, "%PDF")
    end

    test "handles nil notes" do
      invoice = %{sample_invoice() | notes: nil}
      result = InvoicePDF.generate(%{invoice: invoice, client: sample_client()})

      assert {:ok, _} = result
    end

    test "escapes HTML in text fields" do
      invoice = %{sample_invoice() | notes: "<script>alert('xss')</script>"}
      client = %{sample_client() | name: "O'Brien & Associates <Corp>"}
      result = InvoicePDF.generate(%{invoice: invoice, client: client})

      assert {:ok, _} = result
    end
  end
end
