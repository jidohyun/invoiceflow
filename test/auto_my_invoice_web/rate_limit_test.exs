defmodule AutoMyInvoiceWeb.RateLimitTest do
  @moduledoc """
  AMI-15 — rate limit plug + live router integration.

  test env disables the plug by default so the rest of the suite stays
  deterministic. Each test in this file toggles `:rate_limit_enabled`
  on and clears the ETS bucket between scenarios.
  """

  use AutoMyInvoiceWeb.ConnCase, async: false

  alias AutoMyInvoice.RateLimiter

  setup do
    prev = Application.get_env(:auto_my_invoice, :rate_limit_enabled)
    Application.put_env(:auto_my_invoice, :rate_limit_enabled, true)

    on_exit(fn ->
      if is_nil(prev),
        do: Application.delete_env(:auto_my_invoice, :rate_limit_enabled),
        else: Application.put_env(:auto_my_invoice, :rate_limit_enabled, prev)
    end)

    :ok
  end

  describe "POST /api/v1/auth/login (IP bucket, limit 10/min)" do
    test "allows requests under the limit", %{conn: conn} do
      # Use a unique IP per test to avoid bucket bleed from earlier runs.
      ip = unique_ip()

      for _ <- 1..10 do
        conn = post_login(conn, ip)
        # The credentials are bogus — controller returns 401 — but the
        # rate limit must not fire below the threshold.
        refute conn.status == 429
      end
    end

    test "blocks the 11th attempt with 429 + Retry-After + JSON body", %{conn: conn} do
      ip = unique_ip()

      for _ <- 1..10, do: _ = post_login(conn, ip)

      conn = post_login(conn, ip)
      assert conn.status == 429
      assert [retry_after] = Plug.Conn.get_resp_header(conn, "retry-after")
      assert {n, ""} = Integer.parse(retry_after)
      assert n >= 1

      body = Jason.decode!(conn.resp_body)
      assert body["error"] == "rate_limited"
      assert body["retry_after_seconds"] >= 1
    end
  end

  describe "RateLimit plug enable flag" do
    test "is a no-op when :rate_limit_enabled is false", %{conn: conn} do
      Application.put_env(:auto_my_invoice, :rate_limit_enabled, false)
      ip = unique_ip()

      for _ <- 1..30 do
        conn = post_login(conn, ip)
        refute conn.status == 429
      end
    end
  end

  defp post_login(conn, ip) do
    conn
    |> Map.put(:remote_ip, ip)
    |> recycle()
    |> Map.put(:remote_ip, ip)
    |> put_req_header("content-type", "application/json")
    |> post("/api/v1/auth/login", %{"email" => "nope@example.com", "password" => "nope"})
  end

  defp unique_ip do
    # ETS buckets persist across tests in the same VM run, so each test
    # uses a private RFC 5737 documentation IP it's never used before.
    n = System.unique_integer([:positive]) |> rem(254)
    {198, 51, 100, n + 1}
  end

  # Sanity: the limiter itself counts hits per key correctly.
  describe "RateLimiter.hit/3" do
    test "first N hits inside the window allow, then deny" do
      key = "ami15:test:#{System.unique_integer([:positive])}"

      for _ <- 1..3 do
        assert {:allow, _} = RateLimiter.hit(key, 60_000, 3)
      end

      assert {:deny, _ms} = RateLimiter.hit(key, 60_000, 3)
    end
  end
end
