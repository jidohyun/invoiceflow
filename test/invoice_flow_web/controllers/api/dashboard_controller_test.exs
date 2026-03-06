defmodule InvoiceFlowWeb.Api.DashboardControllerTest do
  use InvoiceFlowWeb.ConnCase

  alias InvoiceFlow.Accounts
  alias InvoiceFlowWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "dashtest@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")

    %{user: user, conn: conn}
  end

  describe "GET /api/v1/dashboard" do
    test "returns KPI data", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard")

      assert %{"data" => data} = json_response(conn, 200)
      assert Map.has_key?(data, "outstanding_amount")
      assert Map.has_key?(data, "overdue_count")
      assert Map.has_key?(data, "collection_rate")
      assert Map.has_key?(data, "collected_this_month")
    end
  end

  describe "GET /api/v1/dashboard/recent" do
    test "returns recent invoices", %{conn: conn} do
      conn = get(conn, "/api/v1/dashboard/recent")

      assert %{"data" => invoices} = json_response(conn, 200)
      assert is_list(invoices)
    end
  end
end
