defmodule AutoMyInvoiceWeb.PageController do
  use AutoMyInvoiceWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  @doc """
  AMI-17: Load balancer health probe.

  Returns 200 only when the DB is reachable. Returns 503 + `{"db":"down"}`
  when the Repo can't be queried so platforms like Fly.io stop routing
  traffic. Plain HTTP-safe — this path is excluded from `force_ssl`.
  """
  def health(conn, _params) do
    case AutoMyInvoice.Repo.query("SELECT 1", []) do
      {:ok, _} ->
        conn
        |> put_status(200)
        |> json(%{status: "ok", db: "up"})

      {:error, _reason} ->
        conn
        |> put_status(503)
        |> json(%{status: "degraded", db: "down"})
    end
  end
end
