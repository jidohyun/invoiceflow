defmodule AutoMyInvoiceWeb.BillingLiveTest do
  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.Accounts

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "billing_test@example.com",
        password: "password123456"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  describe "BillingLive" do
    test "renders billing page with current plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "결제"
      assert html =~ "현재 플랜"
      assert html =~ "무료"
    end

    test "shows all plan options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "Starter"
      assert html =~ "Pro"
      assert html =~ "$9"
      assert html =~ "$29"
    end

    test "shows usage progress for free plan", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings/billing")

      assert html =~ "이번 달 송장"
      assert html =~ "0 / 3"
    end

    test "upgrade click shows flash message", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/billing")

      html =
        view
        |> element("button[phx-click=upgrade][phx-value-plan=starter]")
        |> render_click()

      assert html =~ "Paddle 결제창"
    end
  end
end
