defmodule InvoiceFlowWeb.Plugs.ApiAuth do
  @moduledoc "Bearer token authentication plug for REST API endpoints."

  import Plug.Conn

  alias InvoiceFlow.Accounts

  @max_age 86_400 * 30  # 30 days

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {:ok, user_id} <- verify_token(token),
         user when not is_nil(user) <- Accounts.get_user!(user_id) do
      conn
      |> assign(:current_user, user)
      |> assign(:api_token, token)
    else
      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: %{code: "unauthorized", message: "Invalid or missing token"}})
        |> halt()
    end
  end

  @doc "Signs an API token for the given user ID."
  @spec sign_token(binary()) :: binary()
  def sign_token(user_id) do
    Phoenix.Token.sign(InvoiceFlowWeb.Endpoint, "api_auth", user_id)
  end

  @doc "Verifies an API token and returns the user ID."
  @spec verify_token(binary()) :: {:ok, binary()} | {:error, atom()}
  def verify_token(token) do
    Phoenix.Token.verify(InvoiceFlowWeb.Endpoint, "api_auth", token, max_age: @max_age)
  end
end
