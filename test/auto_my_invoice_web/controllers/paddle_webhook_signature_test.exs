defmodule AutoMyInvoiceWeb.PaddleWebhookSignatureTest do
  @moduledoc """
  AMI-14 — HMAC signature + 5-minute replay window + prod no-secret guard.

  These tests temporarily mutate `:paddle_webhook_secret` and `:env` via
  `Application.put_env` so they exercise paths that the default dev
  config short-circuits. Each test restores the originals.
  """

  use AutoMyInvoiceWeb.ConnCase, async: false

  @secret_for_test "test-secret-v1"

  defp with_secret(secret, fun) do
    prev = Application.get_env(:auto_my_invoice, :paddle_webhook_secret)
    Application.put_env(:auto_my_invoice, :paddle_webhook_secret, secret)
    try do
      fun.()
    after
      if is_nil(prev),
        do: Application.delete_env(:auto_my_invoice, :paddle_webhook_secret),
        else: Application.put_env(:auto_my_invoice, :paddle_webhook_secret, prev)
    end
  end

  defp with_env(env, fun) do
    prev = Application.get_env(:auto_my_invoice, :env)
    Application.put_env(:auto_my_invoice, :env, env)
    try do
      fun.()
    after
      Application.put_env(:auto_my_invoice, :env, prev)
    end
  end

  defp valid_signature(body, ts) do
    hash = :crypto.mac(:hmac, :sha256, @secret_for_test, "#{ts}:#{body}") |> Base.encode16(case: :lower)
    "ts=#{ts};h1=#{hash}"
  end

  defp post_webhook(conn, body, signature_header) do
    conn
    |> put_req_header("content-type", "application/json")
    |> put_req_header("paddle-signature", signature_header)
    |> post("/api/webhooks/paddle", body)
  end

  describe "with secret configured" do
    test "accepts a body signed with the right HMAC and a fresh timestamp", %{conn: conn} do
      body = ~s({"event_id":"evt_sig_ok","event_type":"_test","data":{}})
      ts = System.system_time(:second)

      with_secret(@secret_for_test, fn ->
        conn = post_webhook(conn, body, valid_signature(body, ts))
        assert json_response(conn, 200)["status"] in ["ok", "already_processed"]
      end)
    end

    test "rejects a body whose HMAC does not match the signature", %{conn: conn} do
      body = ~s({"event_id":"evt_sig_bad","event_type":"_test","data":{}})
      ts = System.system_time(:second)
      bad = "ts=#{ts};h1=0000000000000000000000000000000000000000000000000000000000000000"

      with_secret(@secret_for_test, fn ->
        conn = post_webhook(conn, body, bad)
        assert json_response(conn, 403)["error"] == "Invalid signature"
      end)
    end

    test "rejects a timestamp older than the 5-minute window (replay)", %{conn: conn} do
      body = ~s({"event_id":"evt_sig_old","event_type":"_test","data":{}})
      stale_ts = System.system_time(:second) - 10 * 60

      with_secret(@secret_for_test, fn ->
        conn = post_webhook(conn, body, valid_signature(body, stale_ts))
        assert json_response(conn, 403)["error"] == "Timestamp outside window"
      end)
    end

    test "rejects a malformed paddle-signature header", %{conn: conn} do
      body = ~s({"event_id":"evt_sig_malformed","event_type":"_test","data":{}})

      with_secret(@secret_for_test, fn ->
        conn = post_webhook(conn, body, "totally-not-a-paddle-signature")
        assert json_response(conn, 403)["error"] == "Invalid signature"
      end)
    end
  end

  describe "without secret configured" do
    test "test env (no secret) lets the request through", %{conn: conn} do
      # default test config has secret = nil — exercise that path
      body = ~s({"event_id":"evt_sig_noprod","event_type":"_test","data":{}})

      conn =
        conn
        |> put_req_header("content-type", "application/json")
        |> post("/api/webhooks/paddle", body)

      assert json_response(conn, 200)["status"] in ["ok", "already_processed"]
    end

    test "prod env with NO secret is rejected (500 Webhook misconfigured)", %{conn: conn} do
      body = ~s({"event_id":"evt_sig_prod_unconfig","event_type":"_test","data":{}})

      with_env(:prod, fn ->
        # explicitly null the secret
        prev = Application.get_env(:auto_my_invoice, :paddle_webhook_secret)
        Application.delete_env(:auto_my_invoice, :paddle_webhook_secret)

        try do
          conn =
            conn
            |> put_req_header("content-type", "application/json")
            |> post("/api/webhooks/paddle", body)

          assert json_response(conn, 500)["error"] == "Webhook misconfigured"
        after
          if not is_nil(prev),
            do: Application.put_env(:auto_my_invoice, :paddle_webhook_secret, prev)
        end
      end)
    end
  end

  describe "raw_body plug" do
    test "the raw_body assign survives Plug.Parsers JSON decoding", %{conn: conn} do
      # If the body reader is wired correctly, the controller can recompute
      # the HMAC against `conn.assigns[:raw_body]`. We exercise the wiring
      # indirectly by sending a real JSON payload with a valid signature —
      # if Plug.Parsers had consumed the body before RawBodyReader stashed
      # it, the HMAC comparison would fail and we'd get 403.
      body = ~s({"event_id":"evt_sig_rawbody","event_type":"_test","data":{"foo":"bar"}})
      ts = System.system_time(:second)

      with_secret(@secret_for_test, fn ->
        conn = post_webhook(conn, body, valid_signature(body, ts))
        assert json_response(conn, 200)["status"] in ["ok", "already_processed"]
      end)
    end
  end
end
