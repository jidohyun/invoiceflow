defmodule InvoiceFlowWeb.Api.ClientControllerTest do
  use InvoiceFlowWeb.ConnCase

  alias InvoiceFlow.{Accounts, Clients}
  alias InvoiceFlowWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "clienttest@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{user: user, conn: conn}
  end

  describe "GET /api/v1/clients" do
    test "lists clients", %{conn: conn, user: user} do
      {:ok, _} = Clients.create_client(user.id, %{name: "Client A", email: "a@test.com"})
      {:ok, _} = Clients.create_client(user.id, %{name: "Client B", email: "b@test.com"})

      conn = get(conn, "/api/v1/clients")

      assert %{"data" => clients, "meta" => %{"total" => 2}} = json_response(conn, 200)
      assert length(clients) == 2
    end
  end

  describe "POST /api/v1/clients" do
    test "creates client with valid data", %{conn: conn} do
      params = %{
        "client" => %{
          "name" => "New Client",
          "email" => "newclient@test.com",
          "company" => "New Co"
        }
      }

      conn = post(conn, "/api/v1/clients", params)

      assert %{"data" => client} = json_response(conn, 201)
      assert client["name"] == "New Client"
    end
  end

  describe "PUT /api/v1/clients/:id" do
    test "updates client", %{conn: conn, user: user} do
      {:ok, client} = Clients.create_client(user.id, %{name: "Old Name", email: "old@test.com"})

      params = %{"client" => %{"name" => "Updated Name"}}
      conn = put(conn, "/api/v1/clients/#{client.id}", params)

      assert %{"data" => updated} = json_response(conn, 200)
      assert updated["name"] == "Updated Name"
    end
  end

  describe "DELETE /api/v1/clients/:id" do
    test "deletes client", %{conn: conn, user: user} do
      {:ok, client} = Clients.create_client(user.id, %{name: "Delete Me", email: "del@test.com"})

      conn = delete(conn, "/api/v1/clients/#{client.id}")
      assert response(conn, 204)
    end
  end
end
