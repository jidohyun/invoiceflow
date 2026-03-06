defmodule InvoiceFlowWeb.Api.ClientController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Clients
  alias InvoiceFlowWeb.Api.{JsonHelpers, FallbackController}

  action_fallback FallbackController

  def index(conn, params) do
    user = conn.assigns.current_user

    opts =
      []
      |> maybe_put(:search, params["q"])

    clients = Clients.list_clients(user.id, opts)
    json(conn, %{data: Enum.map(clients, &JsonHelpers.render_client/1), meta: %{total: length(clients)}})
  end

  def show(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    client = Clients.get_client!(user.id, id)
    json(conn, %{data: JsonHelpers.render_client(client)})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def create(conn, %{"client" => client_params}) do
    user = conn.assigns.current_user

    case Clients.create_client(user.id, client_params) do
      {:ok, client} ->
        conn
        |> put_status(:created)
        |> json(%{data: JsonHelpers.render_client(client)})

      error ->
        error
    end
  end

  def update(conn, %{"id" => id, "client" => client_params}) do
    user = conn.assigns.current_user
    client = Clients.get_client!(user.id, id)

    case Clients.update_client(client, client_params) do
      {:ok, updated} ->
        json(conn, %{data: JsonHelpers.render_client(updated)})

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  def delete(conn, %{"id" => id}) do
    user = conn.assigns.current_user
    client = Clients.get_client!(user.id, id)

    case Clients.delete_client(client) do
      {:ok, _} ->
        conn |> put_status(:no_content) |> text("")

      error ->
        error
    end
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
