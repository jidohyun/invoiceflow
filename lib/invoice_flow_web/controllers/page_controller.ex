defmodule InvoiceFlowWeb.PageController do
  use InvoiceFlowWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
