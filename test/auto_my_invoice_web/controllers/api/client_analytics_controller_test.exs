defmodule AutoMyInvoiceWeb.Api.ClientAnalyticsControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Repo}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "ca-test-#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{user: user, conn: conn}
  end

  defp create_client(user, name, email) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: name,
        email: email,
        company: "Corp",
        timezone: "UTC"
      })

    client
  end

  defp create_paid_invoice(user, client, sent_at, paid_at) do
    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1000.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}
        ]
      })

    invoice
    |> Ecto.Changeset.change(
      status: "paid",
      sent_at: sent_at,
      paid_at: paid_at,
      paid_amount: Decimal.new("1000.00")
    )
    |> Repo.update!()
  end

  describe "GET /api/v1/clients/:id/analytics" do
    test "returns analytics for a client", %{conn: conn, user: user} do
      client = create_client(user, "Analytics Client", "ac@test.com")

      create_paid_invoice(
        user,
        client,
        ~U[2026-01-01 10:00:00Z],
        ~U[2026-01-05 10:00:00Z]
      )

      conn = get(conn, "/api/v1/clients/#{client.id}/analytics")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["invoice_count"] == 1
      assert data["paid_count"] == 1
      assert data["avg_payment_days"] == 4
    end

    test "returns 404 for nonexistent client", %{conn: conn} do
      fake_id = Ecto.UUID.generate()
      conn = get(conn, "/api/v1/clients/#{fake_id}/analytics")
      assert json_response(conn, 404)
    end
  end

  describe "GET /api/v1/clients/ranking" do
    test "returns ranked clients", %{conn: conn, user: user} do
      client = create_client(user, "Ranked Client", "ranked@test.com")

      # Need at least 2 paid invoices
      for _ <- 1..2 do
        create_paid_invoice(
          user,
          client,
          ~U[2026-01-01 10:00:00Z],
          ~U[2026-01-03 10:00:00Z]
        )
      end

      conn = get(conn, "/api/v1/clients/ranking")

      assert %{"data" => ranking} = json_response(conn, 200)
      assert length(ranking) == 1
      assert hd(ranking)["name"] == "Ranked Client"
    end

    test "returns empty list when no clients qualify", %{conn: conn} do
      conn = get(conn, "/api/v1/clients/ranking")

      assert %{"data" => []} = json_response(conn, 200)
    end
  end
end
