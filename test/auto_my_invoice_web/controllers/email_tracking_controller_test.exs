defmodule AutoMyInvoiceWeb.EmailTrackingControllerTest do
  use AutoMyInvoiceWeb.ConnCase

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Repo}
  alias AutoMyInvoice.Reminders.Reminder

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "tracking_test@example.com",
        password: "password123456"
      })

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Track Corp",
        email: "track@corp.com",
        company: "Track"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        invoice_number: "TRK-001",
        amount: Decimal.new("500.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        status: "sent"
      })

    now = DateTime.truncate(DateTime.utc_now(), :second)

    reminder =
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{
        step: 1,
        status: "sent",
        scheduled_at: now,
        sent_at: now
      })
      |> Repo.insert!()

    %{user: user, invoice: invoice, reminder: reminder, conn: build_conn()}
  end

  describe "GET /api/track/open/:reminder_id" do
    test "returns 1x1 transparent GIF", %{conn: conn, reminder: reminder} do
      conn = get(conn, ~p"/api/track/open/#{reminder.id}")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> List.first() =~ "image/gif"
      assert byte_size(conn.resp_body) > 0
    end

    test "records open count and opened_at", %{conn: conn, reminder: reminder} do
      get(conn, ~p"/api/track/open/#{reminder.id}")
      get(conn, ~p"/api/track/open/#{reminder.id}")

      updated = AutoMyInvoice.Repo.get!(AutoMyInvoice.Reminders.Reminder, reminder.id)
      assert updated.open_count == 2
      assert updated.opened_at != nil
    end
  end

  describe "GET /api/track/click/:reminder_id" do
    test "records click and redirects to payment link", %{
      conn: conn,
      reminder: reminder,
      invoice: invoice
    } do
      # Set payment link on invoice
      invoice
      |> Ecto.Changeset.change(%{paddle_payment_link: "https://checkout.paddle.com/test123"})
      |> AutoMyInvoice.Repo.update!()

      conn = get(conn, ~p"/api/track/click/#{reminder.id}")

      assert conn.status == 302
      assert get_resp_header(conn, "location") == ["https://checkout.paddle.com/test123"]

      updated = AutoMyInvoice.Repo.get!(AutoMyInvoice.Reminders.Reminder, reminder.id)
      assert updated.click_count == 1
      assert updated.clicked_at != nil
    end

    test "returns 404 when no payment link", %{conn: conn, reminder: reminder} do
      conn = get(conn, ~p"/api/track/click/#{reminder.id}")

      assert json_response(conn, 404)["error"] =~ "not available"
    end
  end
end
