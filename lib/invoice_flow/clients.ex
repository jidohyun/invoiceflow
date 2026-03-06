defmodule InvoiceFlow.Clients do
  @moduledoc "클라이언트 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Clients.Client

  ## 조회

  @spec list_clients(binary(), keyword()) :: [Client.t()]
  def list_clients(user_id, opts \\ []) do
    sort_by = Keyword.get(opts, :sort_by, :name)
    sort_order = Keyword.get(opts, :sort_order, :asc)
    search = Keyword.get(opts, :search)

    from(c in Client, where: c.user_id == ^user_id)
    |> maybe_search(search)
    |> order_by([c], [{^sort_order, field(c, ^sort_by)}])
    |> Repo.all()
  end

  @spec get_client!(binary(), binary()) :: Client.t()
  def get_client!(user_id, id) do
    Client
    |> Repo.get_by!(id: id, user_id: user_id)
  end

  @spec get_client_by_email(binary(), String.t()) :: Client.t() | nil
  def get_client_by_email(user_id, email) do
    Repo.get_by(Client, user_id: user_id, email: email)
  end

  ## 생성

  @spec create_client(binary(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def create_client(user_id, attrs) do
    %Client{user_id: user_id}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  ## 수정

  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  ## 삭제

  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  ## 내부

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search) do
    term = "%#{search}%"
    from(c in query, where: ilike(c.name, ^term) or ilike(c.email, ^term) or ilike(c.company, ^term))
  end
end
