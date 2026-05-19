defmodule AutoMyInvoiceWeb.CorsTest do
  @moduledoc """
  AMI-20 — CORS allow-list for /api/v1.

  Corsica behaviour:
    * an allowed Origin header is echoed back as Access-Control-Allow-Origin
    * a disallowed Origin is silently ignored (no ACAO header)
    * OPTIONS preflight requests return 200 + ACAO + Access-Control-Allow-Methods

  Tests temporarily override `:cors_origins` via `Application.put_env` so
  the route table doesn't need to be recompiled.
  """

  use AutoMyInvoiceWeb.ConnCase, async: false

  alias AutoMyInvoiceWeb.Cors

  defp with_origins(origins, fun) do
    prev = Application.get_env(:auto_my_invoice, :cors_origins)
    Application.put_env(:auto_my_invoice, :cors_origins, origins)
    try do
      fun.()
    after
      if is_nil(prev),
        do: Application.delete_env(:auto_my_invoice, :cors_origins),
        else: Application.put_env(:auto_my_invoice, :cors_origins, prev)
    end
  end

  describe "Cors.allowed_origins/0" do
    test "parses a comma-separated env var into a list" do
      with_origins("https://a.example.com, https://b.example.com", fn ->
        assert Cors.allowed_origins() == ["https://a.example.com", "https://b.example.com"]
      end)
    end

    test "passes '*' through verbatim" do
      with_origins("*", fn ->
        assert Cors.allowed_origins() == "*"
      end)
    end

    test "empty string falls back to env default" do
      with_origins("", fn ->
        # In test env, default is :self.
        assert Cors.allowed_origins() == :self
      end)
    end

    test "nil falls back to env default" do
      with_origins(nil, fn ->
        assert Cors.allowed_origins() == :self
      end)
    end
  end

  describe "Live API endpoint" do
    test "OPTIONS /api/v1/dashboard with allowed origin returns ACAO + ACAM",
         %{conn: conn} do
      with_origins("https://app.example.com", fn ->
        conn =
          conn
          |> put_req_header("origin", "https://app.example.com")
          |> put_req_header("access-control-request-method", "GET")
          |> options("/api/v1/dashboard")

        assert get_resp_header(conn, "access-control-allow-origin") ==
                 ["https://app.example.com"]

        assert ["GET" <> _ | _] = get_resp_header(conn, "access-control-allow-methods") |> List.wrap()
      end)
    end

    test "GET /api/v1/dashboard with allowed origin echoes ACAO", %{conn: conn} do
      with_origins("https://app.example.com", fn ->
        conn =
          conn
          |> put_req_header("origin", "https://app.example.com")
          |> get("/api/v1/dashboard")

        # Unauthenticated → 401 from ApiAuth, but the CORS header runs before
        # auth and must still be present.
        assert get_resp_header(conn, "access-control-allow-origin") ==
                 ["https://app.example.com"]
      end)
    end

    test "GET /api/v1/dashboard with DISallowed origin omits ACAO", %{conn: conn} do
      with_origins("https://app.example.com", fn ->
        conn =
          conn
          |> put_req_header("origin", "https://evil.example.com")
          |> get("/api/v1/dashboard")

        assert get_resp_header(conn, "access-control-allow-origin") == []
      end)
    end
  end
end
