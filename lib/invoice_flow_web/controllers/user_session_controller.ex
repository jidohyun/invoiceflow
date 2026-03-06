defmodule InvoiceFlowWeb.UserSessionController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Accounts
  alias InvoiceFlowWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    if user = Accounts.get_user_by_email_and_password(email, password) do
      conn
      |> put_flash(:info, "Welcome back!")
      |> UserAuth.log_in_user(user)
    else
      conn
      |> put_flash(:error, "Invalid email or password")
      |> redirect(to: ~p"/users/log_in")
    end
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, "Logged out successfully.")
    |> UserAuth.log_out_user()
  end
end
