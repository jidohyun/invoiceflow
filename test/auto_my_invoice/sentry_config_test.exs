defmodule AutoMyInvoice.SentryConfigTest do
  @moduledoc """
  AMI-19 — Sentry error monitoring wiring.

  We don't dispatch real events from tests (no DSN), so the assertions
  are about *configuration shape*: the library is loaded, the Finch
  child supervised, the PlugContext is in the Endpoint pipeline, and
  the LoggerHandler attach is gated on DSN presence.
  """

  use ExUnit.Case, async: true

  test "Sentry application config carries the v1 hardening defaults" do
    cfg = Application.get_all_env(:sentry)
    assert Keyword.get(cfg, :client) == Sentry.FinchClient
    assert Keyword.get(cfg, :enable_source_code_context) == true
    # dsn is nil in :test by design — no real events
    assert is_nil(Keyword.get(cfg, :dsn))
  end

  test "Sentry.Finch supervisor is supervised" do
    assert Process.whereis(Sentry.Finch) != nil,
           "AMI-19: Finch supervisor (Sentry.Finch) must be in Application children"
  end

  test "Endpoint pipeline includes Sentry.PlugContext" do
    contents = File.read!("lib/auto_my_invoice_web/endpoint.ex")
    assert contents =~ "Sentry.PlugContext",
           "AMI-19: Sentry.PlugContext must be plugged in the Endpoint so request " <>
             "metadata is attached to events"
  end

  test "Application start attaches Sentry.LoggerHandler conditionally on DSN" do
    contents = File.read!("lib/auto_my_invoice/application.ex")
    assert contents =~ "Sentry.LoggerHandler",
           "AMI-19: LoggerHandler must be attached after the supervisor starts"

    # Guard: nothing logs when DSN is nil (current test env).
    assert contents =~ ~r/if Application\.get_env\(:sentry, :dsn\)/,
           "AMI-19: LoggerHandler attach must be gated on a configured DSN"
  end

  test "runtime.exs injects SENTRY_DSN" do
    contents = File.read!("config/runtime.exs")
    assert contents =~ "SENTRY_DSN"
    assert contents =~ "config :sentry, dsn:"
  end
end
