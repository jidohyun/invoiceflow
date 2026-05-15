defmodule AutoMyInvoiceWeb.PaddleWebhookControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Payments}

  defp create_sent_invoice do
    {:ok, user} =
      Accounts.register_user(%{
        email: "paddle-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Paddle Client",
        email: "paddle-client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "UTC"
      })

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

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    {user, sent}
  end

  defp webhook_payload(invoice_id, event_id \\ nil) do
    %{
      "event_id" => event_id || "evt_#{System.unique_integer([:positive])}",
      "event_type" => "transaction.completed",
      "data" => %{
        "id" => "txn_#{System.unique_integer([:positive])}",
        "custom_data" => %{"invoice_id" => invoice_id},
        "details" => %{"totals" => %{"total" => "100000"}},
        "currency_code" => "USD"
      }
    }
  end

  describe "POST /api/webhooks/paddle" do
    test "processes transaction.completed and marks invoice as paid", %{conn: conn} do
      {_user, invoice} = create_sent_invoice()
      payload = webhook_payload(invoice.id)

      conn = post(conn, ~p"/api/webhooks/paddle", payload)

      assert json_response(conn, 200)["status"] == "ok"

      updated = Invoices.get_invoice!(invoice.user_id, invoice.id)
      assert updated.status == "paid"
    end

    test "creates payment record", %{conn: conn} do
      {_user, invoice} = create_sent_invoice()
      payload = webhook_payload(invoice.id)

      post(conn, ~p"/api/webhooks/paddle", payload)

      payments = Payments.list_payments_for_invoice(invoice.id)
      assert length(payments) == 1
      assert hd(payments).status == "completed"
    end

    test "logs webhook event", %{conn: conn} do
      {_user, invoice} = create_sent_invoice()
      event_id = "evt_test_#{System.unique_integer([:positive])}"
      payload = webhook_payload(invoice.id, event_id)

      post(conn, ~p"/api/webhooks/paddle", payload)

      event = Payments.get_webhook_event(event_id)
      assert event != nil
      assert event.event_type == "transaction.completed"
      assert event.processed_at != nil
    end

    test "handles duplicate events idempotently", %{conn: conn} do
      {_user, invoice} = create_sent_invoice()
      event_id = "evt_dup_#{System.unique_integer([:positive])}"
      payload = webhook_payload(invoice.id, event_id)

      conn1 = post(conn, ~p"/api/webhooks/paddle", payload)
      assert json_response(conn1, 200)["status"] == "ok"

      conn2 = post(conn, ~p"/api/webhooks/paddle", payload)
      assert json_response(conn2, 200)["status"] == "already_processed"
    end

    test "handles unknown event types gracefully", %{conn: conn} do
      payload = %{
        "event_id" => "evt_unknown_#{System.unique_integer([:positive])}",
        "event_type" => "subscription.created",
        "data" => %{}
      }

      conn = post(conn, ~p"/api/webhooks/paddle", payload)
      assert json_response(conn, 200)["status"] == "ok"
    end

    test "handles missing invoice gracefully", %{conn: conn} do
      payload = webhook_payload(Ecto.UUID.generate())

      conn = post(conn, ~p"/api/webhooks/paddle", payload)
      assert json_response(conn, 200)["status"] == "ok"
    end
  end
end
