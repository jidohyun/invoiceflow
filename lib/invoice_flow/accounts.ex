defmodule InvoiceFlow.Accounts do
  @moduledoc "사용자 인증 및 프로필 관리 Context"

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

  @spec change_user_registration(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_registration(user, attrs \\ %{}) do
    User.registration_changeset(user, attrs, hash_password: false, validate_email: false)
  end

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

  @spec change_user_profile(User.t(), map()) :: Ecto.Changeset.t()
  def change_user_profile(user, attrs \\ %{}) do
    User.profile_changeset(user, attrs)
  end

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

  ## 송장 생성 권한

  @monthly_invoice_limit %{"free" => 3, "starter" => :unlimited, "pro" => :unlimited}

  @spec can_create_invoice?(User.t()) :: boolean()
  def can_create_invoice?(%User{plan: plan} = user) do
    case Map.get(@monthly_invoice_limit, plan) do
      :unlimited -> true
      limit when is_integer(limit) ->
        count = invoice_count_this_month(user.id)
        count < limit
    end
  end

  defp invoice_count_this_month(user_id) do
    import Ecto.Query

    start_of_month = Date.utc_today() |> Date.beginning_of_month()

    from(i in "invoices",
      where: i.user_id == type(^user_id, :binary_id),
      where: fragment("?::date", i.inserted_at) >= ^start_of_month,
      select: count(i.id)
    )
    |> Repo.one()
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
end
