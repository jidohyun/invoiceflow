defmodule AutoMyInvoiceWeb.Api.InvoiceControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Clients, Invoices}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "invoicetest@example.com",
        password: "password123456"
      })

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Acme Corp",
        email: "billing@acme.com",
        company: "Acme"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{user: user, client: client, conn: conn}
  end

  describe "GET /api/v1/invoices" do
    test "lists invoices for authenticated user", %{conn: conn} do
      conn = get(conn, "/api/v1/invoices")

      assert %{"data" => invoices, "meta" => meta} = json_response(conn, 200)
      assert is_list(invoices)
      assert is_map(meta)
    end
  end

  describe "POST /api/v1/invoices" do
    test "creates invoice with valid data", %{conn: conn, client: client} do
      params = %{
        "invoice" => %{
          "client_id" => client.id,
          "invoice_number" => "INV-001",
          "amount" => "1000.00",
          "currency" => "USD",
          "due_date" => Date.to_iso8601(Date.add(Date.utc_today(), 30)),
          "items" => [
            %{"description" => "Web Development", "quantity" => "10", "unit_price" => "100.00", "position" => 0}
          ]
        }
      }

      conn = post(conn, "/api/v1/invoices", params)

      assert %{"data" => invoice} = json_response(conn, 201)
      assert is_binary(invoice["invoice_number"])
      assert invoice["status"] == "draft"
    end
  end

  describe "GET /api/v1/invoices/:id" do
    test "returns invoice details", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          invoice_number: "INV-SHOW",
          amount: Decimal.new("500"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      conn = get(conn, "/api/v1/invoices/#{invoice.id}")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["id"] == invoice.id
    end

    test "returns 404 for non-existent invoice", %{conn: conn} do
      conn = get(conn, "/api/v1/invoices/#{Ecto.UUID.generate()}")
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/invoices/:id/record_payment" do
    test "records partial payment", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("1000"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)

      conn = post(conn, "/api/v1/invoices/#{sent.id}/record_payment", %{"amount" => "400.00"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["status"] == "partially_paid"
    end

    test "records full payment", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("500"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)

      conn = post(conn, "/api/v1/invoices/#{sent.id}/record_payment", %{"amount" => "500.00"})

      assert %{"data" => data} = json_response(conn, 200)
      assert data["status"] == "paid"
    end

    test "rejects overpayment", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("500"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)

      conn = post(conn, "/api/v1/invoices/#{sent.id}/record_payment", %{"amount" => "999.00"})

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "rejects payment on draft invoice", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("500"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      conn = post(conn, "/api/v1/invoices/#{invoice.id}/record_payment", %{"amount" => "100.00"})

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "returns 404 for non-existent invoice", %{conn: conn} do
      conn = post(conn, "/api/v1/invoices/#{Ecto.UUID.generate()}/record_payment", %{"amount" => "100.00"})
      assert json_response(conn, 404)
    end
  end

  describe "POST /api/v1/invoices/:id/send_reminder" do
    test "sends manual reminder successfully", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("1000"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30),
          items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}]
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)

      conn = post(conn, "/api/v1/invoices/#{sent.id}/send_reminder")

      assert %{"data" => %{"message" => _}} = json_response(conn, 200)
    end

    test "rejects for draft invoice", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          amount: Decimal.new("1000"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30),
          items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}]
        })

      conn = post(conn, "/api/v1/invoices/#{invoice.id}/send_reminder")

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "DELETE /api/v1/invoices/:id" do
    test "deletes draft invoice", %{conn: conn, user: user, client: client} do
      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          client_id: client.id,
          invoice_number: "INV-DEL",
          amount: Decimal.new("100"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30)
        })

      conn = delete(conn, "/api/v1/invoices/#{invoice.id}")
      assert response(conn, 204)
    end
  end
end
