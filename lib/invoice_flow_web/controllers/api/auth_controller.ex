defmodule InvoiceFlowWeb.Api.AuthController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Accounts
  alias InvoiceFlowWeb.Api.{JsonHelpers, FallbackController}
  alias InvoiceFlowWeb.Plugs.ApiAuth

  action_fallback FallbackController

  def register(conn, %{"email" => _, "password" => _} = params) do
    case Accounts.register_user(params) do
      {:ok, user} ->
        token = ApiAuth.sign_token(user.id)

        conn
        |> put_status(:created)
        |> json(%{data: %{token: token, user: JsonHelpers.render_user(user)}})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.get_user_by_email_and_password(email, password) do
      nil ->
        {:error, :unauthorized}

      user ->
        token = ApiAuth.sign_token(user.id)
        json(conn, %{data: %{token: token, user: JsonHelpers.render_user(user)}})
    end
  end

  def refresh(conn, _params) do
    user = conn.assigns.current_user
    token = ApiAuth.sign_token(user.id)
    json(conn, %{data: %{token: token, user: JsonHelpers.render_user(user)}})
  end

  def google(conn, %{"id_token" => id_token}) do
    with {:ok, claims} <- verify_google_id_token(id_token),
         {:ok, user} <- Accounts.find_or_create_oauth_user(%{
           email: claims["email"],
           google_uid: claims["sub"],
           avatar_url: claims["picture"]
         }) do
      token = ApiAuth.sign_token(user.id)
      json(conn, %{data: %{token: token, user: JsonHelpers.render_user(user)}})
    else
      {:error, :invalid_token} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "invalid_token", message: "Invalid Google ID token"}})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def logout(conn, _params) do
    conn
    |> put_status(:no_content)
    |> text("")
  end

  defp verify_google_id_token(_id_token) do
    # TODO: Implement Google ID token verification via Google's tokeninfo endpoint
    # For now, return error to prevent unauthorized access
    {:error, :invalid_token}
  end
end
