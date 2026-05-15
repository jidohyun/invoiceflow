defmodule AutoMyInvoiceWeb.Api.ReminderAnalyticsControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Reminders.Reminder, Repo}
  alias AutoMyInvoiceWeb.Plugs.ApiAuth

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "ra-test-#{System.unique_integer([:positive])}@example.com",
        password: "password123456"
      })

    token = ApiAuth.sign_token(user.id)

    conn =
      build_conn()
      |> put_req_header("authorization", "Bearer #{token}")
      |> put_req_header("content-type", "application/json")

    %{user: user, conn: conn}
  end

  describe "GET /api/v1/analytics/reminders" do
    test "returns reminder effectiveness data", %{conn: conn, user: user} do
      {:ok, client} =
        Clients.create_client(user.id, %{
          name: "Reminder Client",
          email: "rem-ctrl-#{System.unique_integer([:positive])}@test.com",
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
            %{
              description: "Service",
              quantity: Decimal.new(1),
              unit_price: Decimal.new("1000.00")
            }
          ]
        })

      {:ok, sent_invoice} = Invoices.mark_as_sent(invoice)

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      # Create a sent reminder
      %Reminder{invoice_id: sent_invoice.id}
      |> Reminder.changeset(%{step: 1, scheduled_at: now, status: "sent"})
      |> Ecto.Changeset.put_change(:sent_at, now)
      |> Ecto.Changeset.put_change(:opened_at, now)
      |> Ecto.Changeset.put_change(:open_count, 1)
      |> Repo.insert!()

      conn = get(conn, "/api/v1/analytics/reminders")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["total_sent"] == 1
      assert data["total_opened"] == 1
      assert data["overall_open_rate"] == 100.0
      assert is_list(data["by_step"])
      assert is_list(data["avg_days_to_payment"])
    end

    test "returns zeros when no reminders exist", %{conn: conn} do
      conn = get(conn, "/api/v1/analytics/reminders")

      assert %{"data" => data} = json_response(conn, 200)
      assert data["total_sent"] == 0
      assert data["overall_open_rate"] == 0.0
    end
  end
end
