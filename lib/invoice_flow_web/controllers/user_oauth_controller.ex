defmodule InvoiceFlowWeb.UserOauthController do
  use InvoiceFlowWeb, :controller


  def request(conn, _params) do
    conn
    |> put_flash(:error, "Google OAuth is not configured yet. Please use email/password login.")
    |> redirect(to: ~p"/users/log_in")
  end

  def callback(conn, _params) do
    # TODO: Implement Google OAuth callback when credentials are configured
    conn
    |> put_flash(:error, "Google OAuth is not configured yet.")
    |> redirect(to: ~p"/users/log_in")
  end
end
