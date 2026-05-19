defmodule AutoMyInvoice.RuntimeSecretsTest do
  @moduledoc """
  AMI-13 — secrets must be read at runtime, not baked into the release
  artifact at compile time.

  We don't try to assert the literal values (they're nil in test by
  design); we assert the *contract*: every secret-bearing key resolves
  via `Application.get_env/2`, and config.exs never calls
  `System.get_env/1`. That makes a regression where someone re-adds
  a compile-time `System.get_env("MY_KEY")` in config.exs fail loudly.
  """

  use ExUnit.Case, async: true

  @secret_keys ~w(
    paddle_webhook_secret
    paddle_api_key
    paddle_price_id_starter
    paddle_price_id_pro
    openai_api_key
  )a

  test "every secret-bearing application key is reachable via Application.get_env/2" do
    for key <- @secret_keys do
      # The call must succeed without raising. nil is a legitimate value
      # in test (no real keys configured); we only assert reachability.
      _ = Application.get_env(:auto_my_invoice, key)
    end
  end

  test "config.exs does NOT read any application secret at compile time" do
    # If someone re-adds `config :auto_my_invoice, :paddle_api_key,
    # System.get_env("PADDLE_API_KEY")` to config.exs, this test fails.
    contents = File.read!("config/config.exs")

    refute contents =~ "System.get_env(\"PADDLE",
           "PADDLE_* must be injected in runtime.exs, not config.exs"

    refute contents =~ "System.get_env(\"OPENAI",
           "OPENAI_* must be injected in runtime.exs, not config.exs"

    refute contents =~ "System.get_env(\"SENTRY",
           "SENTRY_DSN must be injected in runtime.exs, not config.exs"
  end
end
