defmodule AutoMyInvoice.Emails.ReminderEmailTest do
  use AutoMyInvoice.DataCase

  alias AutoMyInvoice.Emails.ReminderEmail

  defp build_assigns(step) do
    %{
      reminder: %{step: step},
      invoice: %{
        invoice_number: "INV-001",
        amount: Decimal.new("1500.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), -7),
        paddle_payment_link: nil
      },
      client: %{name: "Alice Corp", email: "alice@corp.com"},
      from_email: "noreply@automyinvoice.app"
    }
  end

  describe "build/1" do
    test "step 1 builds friendly reminder email" do
      email = ReminderEmail.build(build_assigns(1))

      assert email.subject =~ "결제 안내"
      assert email.subject =~ "INV-001"
      assert email.subject =~ "$1500.00"
      assert email.html_body =~ "지급 기한"
      assert email.text_body =~ "지급 기한"
      assert [{"Alice Corp", "alice@corp.com"}] = email.to
    end

    test "step 2 builds follow-up email with days overdue" do
      email = ReminderEmail.build(build_assigns(2))

      assert email.subject =~ "확인 요청"
      assert email.subject =~ "연체"
      assert email.html_body =~ "경과일"
    end

    test "step 3 builds final notice email" do
      email = ReminderEmail.build(build_assigns(3))

      assert email.subject =~ "최종 통보"
      assert email.html_body =~ "결제 최종 통보"
      assert email.text_body =~ "최종 통보"
    end

    test "supports KRW currency" do
      assigns = build_assigns(1)
      assigns = put_in(assigns, [:invoice, :currency], "KRW")
      assigns = put_in(assigns, [:invoice, :amount], Decimal.new("150000"))

      email = ReminderEmail.build(assigns)
      assert email.subject =~ "₩150,000"
    end

    test "sets correct from address" do
      email = ReminderEmail.build(build_assigns(1))
      assert {"AutoMyInvoice", "noreply@automyinvoice.app"} = email.from
    end

    test "includes Pay Now button when payment link is present" do
      assigns = build_assigns(1)

      assigns =
        put_in(assigns, [:invoice, :paddle_payment_link], "https://checkout.paddle.com/test")

      email = ReminderEmail.build(assigns)
      assert email.html_body =~ "바로 결제하기"
      assert email.html_body =~ "https://checkout.paddle.com/test"
      assert email.text_body =~ "https://checkout.paddle.com/test"
    end

    test "omits Pay Now button when no payment link" do
      email = ReminderEmail.build(build_assigns(1))
      refute email.html_body =~ "바로 결제하기"
    end

    test "uses user.company_name as from name and applies brand_color to header" do
      assigns =
        build_assigns(1)
        |> Map.put(:user, %{company_name: "코끼리상사", brand_color: "#ff5722"})

      email = ReminderEmail.build(assigns)

      assert {"코끼리상사", "noreply@automyinvoice.app"} = email.from
      assert email.html_body =~ "#ff5722"
    end
  end
end
