# 01 - Accounts Spec

> **구현 완료** | 2026-03-04 | 16 tests 통과
> - User 스키마 (이메일/비밀번호, OAuth, 프로필, 플랜)
> - UserToken 세션 토큰 관리
> - Accounts Context (등록, OAuth, 프로필, 세션, 플랜 검증)
> - 테스트: A-1 ~ A-12 시나리오 커버

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | 사용자 인증, 프로필 관리, OAuth 연동 |
| **Context** | `InvoiceFlow.Accounts` |
| **의존성** | 00-foundation |
| **예상 기간** | Week 1~2 |

---

## 1. Ecto Schemas

### 1.1 User

```elixir
defmodule InvoiceFlow.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :email, :string
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :confirmed_at, :naive_datetime

    # 프로필
    field :company_name, :string
    field :timezone, :string, default: "Asia/Seoul"
    field :brand_tone, :string, default: "professional"  # professional | friendly | formal

    # OAuth
    field :google_uid, :string
    field :avatar_url, :string

    # 구독
    field :plan, :string, default: "free"  # free | starter | pro
    field :paddle_customer_id, :string

    has_many :invoices, InvoiceFlow.Invoices.Invoice
    has_many :clients, InvoiceFlow.Clients.Client

    timestamps(type: :utc_datetime)
  end

  @required_fields [:email]
  @optional_fields [:company_name, :timezone, :brand_tone, :google_uid, :avatar_url, :plan, :paddle_customer_id]

  def registration_changeset(user, attrs, opts \\ []) do
    user
    |> cast(attrs, [:email, :password | @optional_fields])
    |> validate_email(opts)
    |> validate_password(opts)
  end

  def oauth_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :google_uid, :avatar_url, :confirmed_at | @optional_fields])
    |> validate_email([])
    |> unique_constraint(:google_uid)
  end

  def profile_changeset(user, attrs) do
    user
    |> cast(attrs, @optional_fields)
    |> validate_inclusion(:timezone, Tzdata.zone_list())
    |> validate_inclusion(:brand_tone, ~w(professional friendly formal))
    |> validate_inclusion(:plan, ~w(free starter pro))
  end

  defp validate_email(changeset, opts) do
    changeset
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
    |> maybe_validate_unique_email(opts)
  end

  defp validate_password(changeset, opts) do
    changeset
    |> validate_required([:password])
    |> validate_length(:password, min: 8, max: 72)
    |> maybe_hash_password(opts)
  end

  defp maybe_validate_unique_email(changeset, opts) do
    if Keyword.get(opts, :validate_email, true) do
      changeset
      |> unsafe_validate_unique(:email, InvoiceFlow.Repo)
      |> unique_constraint(:email)
    else
      changeset
    end
  end

  defp maybe_hash_password(changeset, opts) do
    hash_password? = Keyword.get(opts, :hash_password, true)
    password = get_change(changeset, :password)

    if hash_password? && password && changeset.valid? do
      changeset
      |> validate_length(:password, max: 72, count: :bytes)
      |> put_change(:hashed_password, Bcrypt.hash_pwd_salt(password))
      |> delete_change(:password)
    else
      changeset
    end
  end
end
```

### 1.2 UserToken

```elixir
defmodule InvoiceFlow.Accounts.UserToken do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @hash_algorithm :sha256
  @rand_size 32

  # 세션 토큰: 60일
  @session_validity_in_days 60
  # 리셋 토큰: 1일
  @reset_password_validity_in_days 1
  # 이메일 확인: 7일
  @confirm_validity_in_days 7

  schema "users_tokens" do
    field :token, :binary
    field :context, :string  # "session" | "reset_password" | "confirm"
    field :sent_to, :string

    belongs_to :user, InvoiceFlow.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end
end
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :hashed_password, :string
      add :confirmed_at, :naive_datetime

      add :company_name, :string
      add :timezone, :string, default: "Asia/Seoul"
      add :brand_tone, :string, default: "professional"

      add :google_uid, :string
      add :avatar_url, :string

      add :plan, :string, default: "free", null: false
      add :paddle_customer_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:google_uid])

    create table(:users_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
```

---

## 3. Context Functions

```elixir
defmodule InvoiceFlow.Accounts do
  @moduledoc "사용자 인증 및 프로필 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Accounts.{User, UserToken}

  ## 조회

  @spec get_user!(binary()) :: User.t()
  def get_user!(id), do: Repo.get!(User, id)

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  ## 등록

  @spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  ## OAuth

  @spec find_or_create_oauth_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def find_or_create_oauth_user(%{email: email, google_uid: uid} = attrs) do
    case Repo.get_by(User, google_uid: uid) || Repo.get_by(User, email: email) do
      nil ->
        %User{}
        |> User.oauth_changeset(Map.put(attrs, :confirmed_at, NaiveDateTime.utc_now()))
        |> Repo.insert()

      user ->
        user
        |> User.oauth_changeset(attrs)
        |> Repo.update()
    end
  end

  ## 프로필

  @spec update_profile(User.t(), map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
  def update_profile(%User{} = user, attrs) do
    user
    |> User.profile_changeset(attrs)
    |> Repo.update()
  end

  ## 세션

  @spec generate_user_session_token(User.t()) :: binary()
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @spec get_user_by_session_token(binary()) :: User.t() | nil
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @spec delete_user_session_token(binary()) :: :ok
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  ## 플랜 확인

  @spec plan_allows?(User.t(), atom()) :: boolean()
  def plan_allows?(%User{plan: plan}, feature) do
    plan_features = %{
      "free" => [:invoice_crud, :basic_template],
      "starter" => [:invoice_crud, :basic_template, :ai_reminders, :paddle_integration, :analytics],
      "pro" => [:invoice_crud, :basic_template, :ai_reminders, :paddle_integration, :analytics, :team, :custom_branding, :api_access]
    }

    feature in Map.get(plan_features, plan, [])
  end

  @spec monthly_invoice_count(User.t()) :: non_neg_integer()
  def monthly_invoice_count(%User{id: user_id}) do
    start_of_month = Date.beginning_of_month(Date.utc_today())

    from(i in InvoiceFlow.Invoices.Invoice,
      where: i.user_id == ^user_id,
      where: fragment("?::date >= ?", i.inserted_at, ^start_of_month),
      select: count(i.id)
    )
    |> Repo.one()
  end

  @spec can_create_invoice?(User.t()) :: boolean()
  def can_create_invoice?(%User{plan: "free"} = user) do
    monthly_invoice_count(user) < 3
  end
  def can_create_invoice?(_user), do: true
end
```

---

## 4. Ueberauth Google OAuth

### 4.1 설정

```elixir
# config/config.exs
config :ueberauth, Ueberauth,
  providers: [
    google: {Ueberauth.Strategy.Google, [default_scope: "email profile"]}
  ]

# config/runtime.exs
config :ueberauth, Ueberauth.Strategy.Google.OAuth,
  client_id: System.get_env("GOOGLE_CLIENT_ID"),
  client_secret: System.get_env("GOOGLE_CLIENT_SECRET")
```

### 4.2 Controller

```elixir
defmodule InvoiceFlowWeb.OAuthController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Accounts

  plug Ueberauth

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    user_attrs = %{
      email: auth.info.email,
      google_uid: auth.uid,
      avatar_url: auth.info.image,
      company_name: auth.info.name
    }

    case Accounts.find_or_create_oauth_user(user_attrs) do
      {:ok, user} ->
        conn
        |> InvoiceFlowWeb.UserAuth.log_in_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "OAuth 인증에 실패했습니다.")
        |> redirect(to: ~p"/log_in")
    end
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "인증에 실패했습니다. 다시 시도해주세요.")
    |> redirect(to: ~p"/log_in")
  end
end
```

---

## 5. LiveView 플로우

### 5.1 로그인 페이지

```
[로그인 페이지]
├─ 이메일/비밀번호 폼
│   └─ submit → UserAuth.log_in_user/2
├─ "Google로 로그인" 버튼
│   └─ GET /auth/google → Ueberauth → callback
└─ "회원가입" 링크
    └─ GET /register → 회원가입 LiveView
```

### 5.2 설정 페이지 (SettingsLive)

```
[설정 페이지]
├─ 프로필 섹션
│   ├─ company_name 입력
│   ├─ timezone 선택 (드롭다운)
│   └─ brand_tone 선택 (radio)
│       └─ handle_event("save_profile") → Accounts.update_profile/2
├─ 플랜 섹션
│   ├─ 현재 플랜 표시
│   └─ "업그레이드" 버튼 → Paddle Checkout
└─ 보안 섹션
    ├─ 비밀번호 변경
    └─ 세션 관리
```

---

## 6. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| A-1 | 이메일/비밀번호로 회원가입 | Unit | User 생성, hashed_password 존재 |
| A-2 | 중복 이메일 회원가입 시도 | Unit | `{:error, changeset}` 반환, unique 에러 |
| A-3 | 비밀번호 8자 미만 거부 | Unit | validation error |
| A-4 | 이메일/비밀번호 로그인 성공 | Unit | `get_user_by_email_and_password/2` 반환 |
| A-5 | 잘못된 비밀번호 로그인 실패 | Unit | nil 반환 |
| A-6 | Google OAuth 최초 로그인 | Unit | 새 User 생성, google_uid 설정 |
| A-7 | Google OAuth 재로그인 | Unit | 기존 User 업데이트 |
| A-8 | 프로필 업데이트 | Unit | company_name, timezone 변경 |
| A-9 | Free 플랜 송장 3건 제한 | Unit | 4번째 `can_create_invoice?/1` → false |
| A-10 | Starter 플랜 무제한 송장 | Unit | `can_create_invoice?/1` → true |
| A-11 | 세션 토큰 생성/검증 | Unit | 토큰으로 사용자 조회 성공 |
| A-12 | 세션 토큰 삭제 | Unit | 삭제 후 조회 시 nil |
| A-13 | 로그인 LiveView 렌더링 | Integration | 폼 요소 존재 확인 |
| A-14 | 설정 페이지 프로필 수정 | Integration | LiveView 이벤트 → DB 업데이트 |
