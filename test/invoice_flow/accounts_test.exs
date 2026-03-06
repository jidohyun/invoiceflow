defmodule InvoiceFlow.AccountsTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Accounts
  alias InvoiceFlow.Accounts.User

  describe "register_user/1" do
    # A-1: 이메일/비밀번호로 회원가입
    test "creates user with valid email and password" do
      attrs = %{email: "test@example.com", password: "validpassword123"}
      assert {:ok, %User{} = user} = Accounts.register_user(attrs)
      assert user.email == "test@example.com"
      assert user.hashed_password != nil
      assert user.password == nil
      assert user.plan == "free"
      assert user.timezone == "Asia/Seoul"
    end

    # A-2: 중복 이메일 회원가입 시도
    test "rejects duplicate email" do
      attrs = %{email: "dupe@example.com", password: "validpassword123"}
      assert {:ok, _} = Accounts.register_user(attrs)
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert {"has already been taken", _} = changeset.errors[:email]
    end

    # A-3: 비밀번호 8자 미만 거부
    test "rejects password shorter than 8 characters" do
      attrs = %{email: "short@example.com", password: "short"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert {"should be at least %{count} character(s)", _} = changeset.errors[:password]
    end

    test "rejects missing email" do
      attrs = %{password: "validpassword123"}
      assert {:error, changeset} = Accounts.register_user(attrs)
      assert {"can't be blank", _} = changeset.errors[:email]
    end
  end

  describe "get_user_by_email_and_password/2" do
    # A-4: 이메일/비밀번호 로그인 성공
    test "returns user with correct credentials" do
      {:ok, user} = Accounts.register_user(%{email: "login@example.com", password: "validpassword123"})
      found = Accounts.get_user_by_email_and_password("login@example.com", "validpassword123")
      assert found.id == user.id
    end

    # A-5: 잘못된 비밀번호 로그인 실패
    test "returns nil with wrong password" do
      Accounts.register_user(%{email: "wrong@example.com", password: "validpassword123"})
      assert Accounts.get_user_by_email_and_password("wrong@example.com", "wrongpassword") == nil
    end

    test "returns nil with nonexistent email" do
      assert Accounts.get_user_by_email_and_password("noone@example.com", "password123") == nil
    end
  end

  describe "find_or_create_oauth_user/1" do
    # A-6: Google OAuth 최초 로그인
    test "creates new user on first OAuth login" do
      attrs = %{
        email: "oauth@example.com",
        google_uid: "google-123",
        avatar_url: "https://example.com/avatar.png"
      }

      assert {:ok, %User{} = user} = Accounts.find_or_create_oauth_user(attrs)
      assert user.email == "oauth@example.com"
      assert user.google_uid == "google-123"
      assert user.confirmed_at != nil
    end

    # A-7: Google OAuth 재로그인
    test "updates existing user on subsequent OAuth login" do
      attrs = %{
        email: "oauth2@example.com",
        google_uid: "google-456",
        avatar_url: "https://example.com/old.png"
      }

      {:ok, original} = Accounts.find_or_create_oauth_user(attrs)

      updated_attrs = Map.put(attrs, :avatar_url, "https://example.com/new.png")
      {:ok, updated} = Accounts.find_or_create_oauth_user(updated_attrs)

      assert updated.id == original.id
      assert updated.avatar_url == "https://example.com/new.png"
    end
  end

  describe "update_profile/2" do
    # A-8: 프로필 업데이트
    test "updates company_name and timezone" do
      {:ok, user} = Accounts.register_user(%{email: "profile@example.com", password: "validpassword123"})

      assert {:ok, updated} =
               Accounts.update_profile(user, %{
                 company_name: "Test Corp",
                 timezone: "America/New_York",
                 brand_tone: "friendly"
               })

      assert updated.company_name == "Test Corp"
      assert updated.timezone == "America/New_York"
      assert updated.brand_tone == "friendly"
    end

    test "rejects invalid brand_tone" do
      {:ok, user} = Accounts.register_user(%{email: "tone@example.com", password: "validpassword123"})
      assert {:error, changeset} = Accounts.update_profile(user, %{brand_tone: "invalid"})
      assert {"is invalid", _} = changeset.errors[:brand_tone]
    end
  end

  describe "plan_allows?/2" do
    # A-9, A-10
    test "free plan allows basic features" do
      user = %User{plan: "free"}
      assert Accounts.plan_allows?(user, :invoice_crud)
      assert Accounts.plan_allows?(user, :basic_template)
      refute Accounts.plan_allows?(user, :ai_reminders)
    end

    test "starter plan allows ai_reminders" do
      user = %User{plan: "starter"}
      assert Accounts.plan_allows?(user, :ai_reminders)
      assert Accounts.plan_allows?(user, :paddle_integration)
      refute Accounts.plan_allows?(user, :team)
    end

    test "pro plan allows all features" do
      user = %User{plan: "pro"}
      assert Accounts.plan_allows?(user, :team)
      assert Accounts.plan_allows?(user, :custom_branding)
      assert Accounts.plan_allows?(user, :api_access)
    end
  end

  describe "session tokens" do
    # A-11, A-12
    test "generates and verifies session token" do
      {:ok, user} = Accounts.register_user(%{email: "session@example.com", password: "validpassword123"})
      token = Accounts.generate_user_session_token(user)
      assert is_binary(token)

      found = Accounts.get_user_by_session_token(token)
      assert found.id == user.id
    end

    test "deletes session token" do
      {:ok, user} = Accounts.register_user(%{email: "delete@example.com", password: "validpassword123"})
      token = Accounts.generate_user_session_token(user)
      assert Accounts.get_user_by_session_token(token) != nil

      Accounts.delete_user_session_token(token)
      assert Accounts.get_user_by_session_token(token) == nil
    end
  end
end
