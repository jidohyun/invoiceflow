defmodule AutoMyInvoice.Emails.InvoiceEmailTest do
  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.Emails.InvoiceEmail

  defp build_invoice(attrs \\ %{}) do
    base = %{
      invoice_number: "INV-2026-0001",
      amount: Decimal.new(1500),
      currency: "KRW",
      due_date: ~D[2026-06-30],
      notes: nil
    }

    Map.merge(base, attrs)
  end

  defp build_client(attrs \\ %{}) do
    base = %{name: "테스트클라이언트", email: "client@example.com"}
    Map.merge(base, attrs)
  end

  defp build_user(attrs \\ %{}) do
    base = %{company_name: nil, brand_color: nil}
    Map.merge(base, attrs)
  end

  describe "invoice_sent/1 — default (no user)" do
    test "uses AutoMyInvoice as from name when user is absent (backward-compat)" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(),
          client: build_client(),
          from_email: "noreply@automyinvoice.app"
        })

      assert {"AutoMyInvoice", "noreply@automyinvoice.app"} = email.from
    end

    test "renders amount with thousand separator and KRW symbol" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(%{amount: Decimal.new(1_500_000)}),
          client: build_client(),
          from_email: "noreply@automyinvoice.app"
        })

      assert email.html_body =~ "₩1,500,000"
      assert email.text_body =~ "₩1,500,000"
    end
  end

  describe "invoice_sent/1 — brand-aware (user provided)" do
    test "uses user.company_name as from name when present" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(),
          client: build_client(),
          from_email: "noreply@automyinvoice.app",
          user: build_user(%{company_name: "주식회사 코끼리"})
        })

      assert {"주식회사 코끼리", "noreply@automyinvoice.app"} = email.from
    end

    test "falls back to AutoMyInvoice when company_name is nil even if user is given" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(),
          client: build_client(),
          from_email: "noreply@automyinvoice.app",
          user: build_user()
        })

      assert {"AutoMyInvoice", "noreply@automyinvoice.app"} = email.from
    end

    test "applies brand_color to header background when present" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(),
          client: build_client(),
          from_email: "noreply@automyinvoice.app",
          user: build_user(%{brand_color: "#ff5722"})
        })

      assert email.html_body =~ "#ff5722"
    end

    test "company_name appears in HTML footer when set" do
      email =
        InvoiceEmail.invoice_sent(%{
          invoice: build_invoice(),
          client: build_client(),
          from_email: "noreply@automyinvoice.app",
          user: build_user(%{company_name: "주식회사 코끼리"})
        })

      assert email.html_body =~ "주식회사 코끼리"
    end
  end
end
