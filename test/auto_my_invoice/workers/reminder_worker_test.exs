defmodule AutoMyInvoice.Workers.ReminderWorkerTest do
  use AutoMyInvoice.DataCase
  use Oban.Testing, repo: AutoMyInvoice.Repo

  alias AutoMyInvoice.Workers.ReminderWorker
  alias AutoMyInvoice.Reminders.Reminder
  alias AutoMyInvoice.{Accounts, Clients, Invoices}

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "rw-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_sent_invoice(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "RW Client",
        email: "rw-client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "UTC"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("500.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("500.00")}
        ]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    Repo.preload(sent, :client)
  end

  defp create_reminder(invoice, step, status \\ "scheduled") do
    scheduled_at = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)

    {:ok, reminder} =
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: status})
      |> Repo.insert()

    reminder
  end

  describe "perform/1" do
    test "sends reminder email and updates status to sent" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1)

      assert :ok = perform_job(ReminderWorker, %{reminder_id: reminder.id})

      updated = Repo.get!(Reminder, reminder.id)
      assert updated.status == "sent"
      assert updated.sent_at != nil
    end

    test "skips already sent reminder" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "sent")

      assert {:cancel, _} = perform_job(ReminderWorker, %{reminder_id: reminder.id})
    end

    test "skips cancelled reminder" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "cancelled")

      assert {:cancel, _} = perform_job(ReminderWorker, %{reminder_id: reminder.id})
    end

    test "cancels when reminder not found" do
      assert {:cancel, _} = perform_job(ReminderWorker, %{reminder_id: Ecto.UUID.generate()})
    end

    test "sends step 2 email with different tone" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 2)

      assert :ok = perform_job(ReminderWorker, %{reminder_id: reminder.id})

      updated = Repo.get!(Reminder, reminder.id)
      assert updated.status == "sent"
    end

    test "sends step 3 (final notice) email" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 3)

      assert :ok = perform_job(ReminderWorker, %{reminder_id: reminder.id})

      updated = Repo.get!(Reminder, reminder.id)
      assert updated.status == "sent"
    end
  end
end
