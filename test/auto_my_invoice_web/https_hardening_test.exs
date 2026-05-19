defmodule AutoMyInvoiceWeb.HttpsHardeningTest do
  @moduledoc """
  AMI-17 — HTTPS force_ssl + HSTS hardening + /health load-balancer probe.

  Some of the behaviour we want is compile-time (force_ssl runs as a
  Plug at boot and reads `config :auto_my_invoice, Endpoint,
  force_ssl: ...`). We can't usefully toggle that mid-test without
  recompiling the Endpoint, so we assert the config shape directly —
  if anyone weakens HSTS, removes preload, or forgets to exclude
  health, this test fires.

  The /health probe itself goes through the live Endpoint.
  """

  use AutoMyInvoiceWeb.ConnCase, async: false

  describe "GET /health" do
    test "returns 200 + db:up when the Repo is reachable", %{conn: conn} do
      conn = get(conn, "/health")
      body = json_response(conn, 200)
      assert body["status"] == "ok"
      assert body["db"] == "up"
    end
  end

  describe "force_ssl config (compile-time, asserted from Application env)" do
    setup do
      cfg = Application.get_env(:auto_my_invoice, AutoMyInvoiceWeb.Endpoint, [])
      force_ssl = Keyword.get(cfg, :force_ssl, [])
      %{force_ssl: force_ssl}
    end

    @tag :force_ssl_config
    test "force_ssl is set in :prod and skipped in :dev/:test", %{force_ssl: force_ssl} do
      case Application.get_env(:auto_my_invoice, :env) do
        :prod ->
          assert force_ssl != []

        _ ->
          assert force_ssl == []
      end
    end

    @tag :force_ssl_config
    test ":prod force_ssl pins HSTS + preload + 1-year expiry + edge proxy rewrite", %{force_ssl: force_ssl} do
      # In dev/test the force_ssl key is empty (correct — we don't want
      # HSTS on localhost). The shape assertion below is meaningful only
      # in prod; skip otherwise.
      if Application.get_env(:auto_my_invoice, :env) != :prod do
        :ok
      else
        assert Keyword.get(force_ssl, :hsts) == true
        assert Keyword.get(force_ssl, :preload) == true
        assert Keyword.get(force_ssl, :subdomains) == true
        assert Keyword.get(force_ssl, :expires) == 31_536_000
        assert :x_forwarded_proto in Keyword.get(force_ssl, :rewrite_on, [])

        exclude = Keyword.get(force_ssl, :exclude, [])
        assert "/health" in exclude,
               "force_ssl exclude must list /health so load balancers can probe over plain HTTP"
      end
    end
  end

  describe "prod.exs config file (text-level guard against regressions)" do
    setup do
      %{contents: File.read!("config/prod.exs")}
    end

    test "force_ssl block contains the required hardening flags", %{contents: contents} do
      assert contents =~ "force_ssl:"
      assert contents =~ "rewrite_on: [:x_forwarded_proto]"
      assert contents =~ "hsts: true"
      assert contents =~ "preload: true"
      assert contents =~ "subdomains: true"
      assert contents =~ "expires: 31_536_000"
      assert contents =~ ~s("/health")
    end
  end
end
