defmodule AutoMyInvoice.Emails.OverdueEmailTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Emails.OverdueEmail

  defp build_assigns do
    %{
      invoice: %{
        invoice_number: "INV-202603-ABCD",
        amount: Decimal.new("2500.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), -10),
        paddle_payment_link: nil
      },
      client: %{name: "Acme Corp", email: "billing@acme.com"},
      from_email: "noreply@automyinvoice.app"
    }
  end

  describe "build/1" do
    test "builds overdue notification email with correct subject and body" do
      email = OverdueEmail.build(build_assigns())

      assert email.subject =~ "연체 알림"
      assert email.subject =~ "INV-202603-ABCD"
      assert email.subject =~ "$2500.00"
      assert email.subject =~ "미납"

      assert email.html_body =~ "연체 알림"
      assert email.html_body =~ "INV-202603-ABCD"
      assert email.html_body =~ "$2500.00"
      assert email.html_body =~ "10일"

      assert email.text_body =~ "INV-202603-ABCD"
      assert email.text_body =~ "$2500.00"
      assert email.text_body =~ "10일"

      assert [{"Acme Corp", "billing@acme.com"}] = email.to
      assert {"AutoMyInvoice", "noreply@automyinvoice.app"} = email.from
    end

    test "supports KRW currency" do
      assigns = build_assigns()
      assigns = put_in(assigns, [:invoice, :currency], "KRW")
      assigns = put_in(assigns, [:invoice, :amount], Decimal.new("250000"))

      email = OverdueEmail.build(assigns)
      assert email.subject =~ "₩250000"
    end

    test "includes payment link when present" do
      assigns = build_assigns()
      assigns = put_in(assigns, [:invoice, :paddle_payment_link], "https://checkout.paddle.com/overdue-test")

      email = OverdueEmail.build(assigns)
      assert email.html_body =~ "지금 결제하기"
      assert email.html_body =~ "https://checkout.paddle.com/overdue-test"
      assert email.text_body =~ "https://checkout.paddle.com/overdue-test"
    end

    test "omits payment button when no payment link" do
      email = OverdueEmail.build(build_assigns())
      refute email.html_body =~ "지금 결제하기"
    end
  end
end
