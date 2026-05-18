defmodule AutoMyInvoice.AccountsResetPasswordTest do
  @moduledoc """
  AMI-87 — password reset token issuance, verification, and full reset flow.

  Touches: Accounts.deliver_user_reset_password_instructions/2,
  Accounts.get_user_by_reset_password_token/1, Accounts.reset_user_password/2,
  Accounts.UserToken.{build_email_token/2, verify_email_token_query/2}.
  """

  use AutoMyInvoice.DataCase, async: true

  import Swoosh.TestAssertions

  alias AutoMyInvoice.Accounts
  alias AutoMyInvoice.Accounts.{User, UserToken}
  alias AutoMyInvoice.Repo

  defp register_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email, "reset-#{System.unique_integer([:positive])}@example.com")
    password = Map.get(attrs, :password, "OriginalPass123!")

    {:ok, user} = Accounts.register_user(%{email: email, password: password})
    user
  end

  describe "deliver_user_reset_password_instructions/2" do
    test "stores a hashed token and emails the user the plain token URL" do
      user = register_user!()

      {:ok, _email} =
        Accounts.deliver_user_reset_password_instructions(user, fn token ->
          "http://test.local/users/reset_password/#{token}"
        end)

      stored = Repo.get_by(UserToken, user_id: user.id, context: "reset_password")
      assert stored, "expected a reset_password token row in users_tokens"
      assert stored.sent_to == user.email

      # The stored token must be the SHA-256 hash, not the plain token. SHA-256
      # is always 32 bytes — anything else means we stored the plain token
      # by mistake and a DB leak would let an attacker complete the reset.
      assert is_binary(stored.token)
      assert byte_size(stored.token) == 32

      assert_email_sent(fn email ->
        assert email.to == [{user.email, user.email}]
        assert email.subject =~ "비밀번호 재설정"
      end)
    end
  end

  describe "get_user_by_reset_password_token/1" do
    test "returns the user for a freshly issued token" do
      user = register_user!()

      {encoded, user_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      assert %User{id: user_id} = Accounts.get_user_by_reset_password_token(encoded)
      assert user_id == user.id
    end

    test "returns nil for a tampered token" do
      user = register_user!()

      {encoded, user_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(user_token)

      # Issue a completely different token and use *its* encoded form — the
      # stored hash will not match, so verification must fail. (Flipping a
      # single trailing character of a url-safe base64 string can decode to
      # an identical byte sequence because of the unused trailing bits, so
      # we use a fully independent token here.)
      {other_encoded, _other_token} = UserToken.build_email_token(user, "reset_password")
      refute other_encoded == encoded
      assert Accounts.get_user_by_reset_password_token(other_encoded) == nil
    end

    test "returns nil for an expired token" do
      user = register_user!()

      {encoded, user_token} = UserToken.build_email_token(user, "reset_password")
      {:ok, inserted} = Repo.insert(user_token)

      # Backdate past the 1-day validity window.
      Repo.update_all(
        from(t in UserToken, where: t.id == ^inserted.id),
        set: [inserted_at: DateTime.add(DateTime.utc_now(), -2, :day) |> DateTime.truncate(:second)]
      )

      assert Accounts.get_user_by_reset_password_token(encoded) == nil
    end
  end

  describe "reset_user_password/2" do
    test "updates the password hash and invalidates every existing token for the user" do
      user = register_user!(%{password: "OriginalPass123!"})

      _session_token = Accounts.generate_user_session_token(user)
      {_encoded, reset_token} = UserToken.build_email_token(user, "reset_password")
      Repo.insert!(reset_token)

      assert Repo.aggregate(
               UserToken.by_user_and_contexts_query(user, ["session", "reset_password"]),
               :count
             ) == 2

      {:ok, updated} =
        Accounts.reset_user_password(user, %{
          password: "BrandNewPass456!",
          password_confirmation: "BrandNewPass456!"
        })

      assert updated.hashed_password != user.hashed_password
      assert User.valid_password?(updated, "BrandNewPass456!")
      refute User.valid_password?(updated, "OriginalPass123!")

      # All session + reset tokens for this user are wiped so the old session
      # cookie and the link in the user's inbox can no longer be replayed.
      assert Repo.aggregate(
               UserToken.by_user_and_contexts_query(user, ["session", "reset_password"]),
               :count
             ) == 0
    end

    test "returns a changeset error when password confirmation does not match" do
      user = register_user!()

      assert {:error, changeset} =
               Accounts.reset_user_password(user, %{
                 password: "BrandNewPass456!",
                 password_confirmation: "Mismatch!!!"
               })

      assert "비밀번호가 일치하지 않습니다" in (changeset
                                                 |> errors_on()
                                                 |> Map.get(:password_confirmation, []))
    end

    test "returns a changeset error when password is too short" do
      user = register_user!()

      assert {:error, changeset} =
               Accounts.reset_user_password(user, %{
                 password: "short",
                 password_confirmation: "short"
               })

      assert Map.has_key?(errors_on(changeset), :password)
    end
  end
end
