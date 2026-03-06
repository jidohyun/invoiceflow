defmodule InvoiceFlowWeb.PageControllerTest do
  use InvoiceFlowWeb.ConnCase

  test "GET / redirects unauthenticated users to login", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == "/users/log_in"
  end
end
