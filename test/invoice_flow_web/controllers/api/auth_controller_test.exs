defmodule InvoiceFlowWeb.Api.AuthControllerTest do
  use InvoiceFlowWeb.ConnCase

  alias InvoiceFlow.Accounts
  alias InvoiceFlowWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "test@example.com",
        password: "password123456"
      })

    %{user: user}
  end

  describe "POST /api/v1/auth/register" do
    test "creates account and returns token", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          email: "new@example.com",
          password: "password123456"
        })

      assert %{"data" => %{"token" => token, "user" => user}} = json_response(conn, 201)
      assert is_binary(token)
      assert user["email"] == "new@example.com"
    end

    test "returns error for duplicate email", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/register", %{
          email: "test@example.com",
          password: "password123456"
        })

      assert %{"error" => %{"code" => "validation_error"}} = json_response(conn, 422)
    end
  end

  describe "POST /api/v1/auth/login" do
    test "returns token for valid credentials", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          email: "test@example.com",
          password: "password123456"
        })

      assert %{"data" => %{"token" => token, "user" => user}} = json_response(conn, 200)
      assert is_binary(token)
      assert user["email"] == "test@example.com"
    end

    test "returns error for invalid credentials", %{conn: conn} do
      conn =
        post(conn, "/api/v1/auth/login", %{
          email: "test@example.com",
          password: "wrong"
        })

      assert %{"error" => %{"code" => "unauthorized"}} = json_response(conn, 401)
    end
  end

  describe "POST /api/v1/auth/refresh" do
    test "returns new token for authenticated user", %{conn: conn, user: user} do
      token = ApiAuth.sign_token(user.id)

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{token}")
        |> post("/api/v1/auth/refresh")

      assert %{"data" => %{"token" => new_token}} = json_response(conn, 200)
      assert is_binary(new_token)
    end

    test "returns 401 without token", %{conn: conn} do
      conn = post(conn, "/api/v1/auth/refresh")
      assert json_response(conn, 401)
    end
  end
end
