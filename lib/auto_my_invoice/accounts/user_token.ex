defmodule AutoMyInvoice.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @rand_size 32
  @session_validity_in_days 60
  @reset_password_validity_in_days 1
  @hash_algorithm :sha256

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    field :sent_to, :string

    belongs_to :user, AutoMyInvoice.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %__MODULE__{token: token, context: "session", user_id: user.id}}
  end

  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  def by_token_and_context_query(token, context) do
    from __MODULE__, where: [token: ^token, context: ^context]
  end

  # ── reset_password token ──────────────────────────────────────────
  # Plain token goes in the URL we email to the user. Only its hash is
  # stored in the DB so a leak of the users_tokens table can't be used
  # to log anyone in.

  def build_email_token(user, context) when context in ~w(reset_password) do
    token = :crypto.strong_rand_bytes(@rand_size)
    hashed_token = :crypto.hash(@hash_algorithm, token)

    {Base.url_encode64(token, padding: false),
     %__MODULE__{
       token: hashed_token,
       context: context,
       sent_to: user.email,
       user_id: user.id
     }}
  end

  def verify_email_token_query(token, "reset_password") do
    case Base.url_decode64(token, padding: false) do
      {:ok, decoded_token} ->
        hashed_token = :crypto.hash(@hash_algorithm, decoded_token)

        query =
          from t in by_token_and_context_query(hashed_token, "reset_password"),
            join: user in assoc(t, :user),
            where: t.inserted_at > ago(@reset_password_validity_in_days, "day") and
                     t.sent_to == user.email,
            select: user

        {:ok, query}

      :error ->
        :error
    end
  end

  def by_user_and_contexts_query(user, contexts) do
    from t in __MODULE__, where: t.user_id == ^user.id and t.context in ^contexts
  end
end
