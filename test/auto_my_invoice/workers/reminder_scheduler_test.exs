defmodule AutoMyInvoice.Workers.ReminderSchedulerTest do
  use AutoMyInvoice.DataCase
  use Oban.Testing, repo: AutoMyInvoice.Repo

  alias AutoMyInvoice.Workers.ReminderScheduler
  alias AutoMyInvoice.Reminders.Reminder
  alias AutoMyInvoice.{Accounts, Clients, Invoices}

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "rs-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_sent_invoice(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "RS Client",
        email: "rs-client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "UTC"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("300.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("300.00")}
        ]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    Repo.preload(sent, :client)
  end

  defp create_reminder(invoice, step, scheduled_at, status \\ "scheduled") do
    {:ok, reminder} =
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: status})
      |> Repo.insert()

    reminder
  end

  describe "perform/1" do
    test "enqueues ReminderWorker for due reminders" do
      user = create_user()
      invoice = create_sent_invoice(user)

      past = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)
      _due_reminder = create_reminder(invoice, 1, past)

      assert :ok = perform_job(ReminderScheduler, %{})
    end

    test "does not enqueue for future reminders" do
      user = create_user()
      invoice = create_sent_invoice(user)

      future = DateTime.add(DateTime.utc_now(), 86400, :second) |> DateTime.truncate(:second)
      _future_reminder = create_reminder(invoice, 1, future)

      assert :ok = perform_job(ReminderScheduler, %{})

      # Future reminder should remain scheduled
      reminders = AutoMyInvoice.Reminders.list_reminders_for_invoice(invoice.id)
      assert Enum.all?(reminders, &(&1.status == "scheduled"))
    end

    test "skips already sent reminders" do
      user = create_user()
      invoice = create_sent_invoice(user)

      past = DateTime.add(DateTime.utc_now(), -3600, :second) |> DateTime.truncate(:second)
      _sent_reminder = create_reminder(invoice, 1, past, "sent")

      assert :ok = perform_job(ReminderScheduler, %{})
    end
  end
end
