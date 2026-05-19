defmodule AutoMyInvoice.MailerConfigTest do
  @moduledoc """
  AMI-16 — mailer configuration & sender_email plumbing.

  We don't try to dispatch real SMTP from tests; instead we lock in:
    1. The Mailer adapter remains Swoosh.Adapters.Test in :test
       (otherwise the suite would either hit the network or queue mail
       to disk).
    2. `:sender_email` is wired through Application env so deployers
       can swap it via MAILER_FROM without touching code.
    3. UserNotifier reads sender_email from the same key (regression
       guard against the old hard-coded `@from_email` constant).
  """

  use AutoMyInvoice.DataCase, async: false

  import Swoosh.TestAssertions

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Repo

  defp register_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email, "mail-#{System.unique_integer([:positive])}@example.com")
    {:ok, user} = Accounts.register_user(%{email: email, password: "ValidPassword123!"})
    user
  end

  test "Mailer adapter in :test is Swoosh.Adapters.Test" do
    cfg = Application.get_env(:auto_my_invoice, AutoMyInvoice.Mailer, [])
    assert Keyword.get(cfg, :adapter) == Swoosh.Adapters.Test
  end

  test ":sender_email is configurable via Application env" do
    prev = Application.get_env(:auto_my_invoice, :sender_email)

    try do
      Application.put_env(:auto_my_invoice, :sender_email, "ami16@example.com")
      user = register_user!()

      {:ok, _} =
        AutoMyInvoice.Accounts.deliver_user_reset_password_instructions(
          user,
          fn token -> "http://test.local/users/reset_password/#{token}" end
        )

      assert_email_sent(fn email ->
        assert email.from == {"AutoMyInvoice", "ami16@example.com"}
      end)
    after
      if is_nil(prev),
        do: Application.delete_env(:auto_my_invoice, :sender_email),
        else: Application.put_env(:auto_my_invoice, :sender_email, prev)
    end
  end

  test "runtime.exs lays out the MAILER_ADAPTER decision table" do
    contents = File.read!("config/runtime.exs")
    assert contents =~ "MAILER_ADAPTER"
    assert contents =~ "Swoosh.Adapters.SMTP"
    assert contents =~ "MAILER_SMTP_RELAY"
    # required-when-smtp guard is loud
    assert contents =~ "MAILER_ADAPTER=smtp requires MAILER_SMTP_RELAY"
  end

  test ".env.example documents the mailer + SMTP keys" do
    env = File.read!(".env.example")
    assert env =~ "MAILER_ADAPTER"
    assert env =~ "MAILER_FROM"
    assert env =~ "MAILER_SMTP_RELAY"
    assert env =~ "MAILER_SMTP_USERNAME"
    assert env =~ "MAILER_SMTP_PASSWORD"
  end

  # Touch Repo so async: false + DataCase setup compiles cleanly.
  test "data case sanity (no-op DB query)" do
    assert {:ok, _} = Repo.query("SELECT 1")
  end
end
