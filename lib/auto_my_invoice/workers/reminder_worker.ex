defmodule AutoMyInvoice.Workers.ReminderWorker do
  @moduledoc """
  Oban Worker that sends a single reminder email.

  Receives a reminder_id, loads the reminder + invoice + client,
  builds the email via ReminderEmail, delivers via Swoosh,
  and updates the reminder status to "sent".
  """

  use Oban.Worker, queue: :reminders, max_attempts: 5

  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Reminders.Reminder
  alias AutoMyInvoice.Emails.ReminderEmail
  alias AutoMyInvoice.Mailer
  alias AutoMyInvoice.PubSubTopics

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"reminder_id" => reminder_id}}) do
    reminder =
      Reminder
      |> Repo.get(reminder_id)
      |> Repo.preload(invoice: :client)

    case reminder do
      nil ->
        {:cancel, "reminder #{reminder_id} not found"}

      %{status: status} when status in ~w(sent cancelled) ->
        {:cancel, "reminder already #{status}"}

      %{invoice: nil} ->
        {:cancel, "invoice not found for reminder"}

      reminder ->
        send_reminder(reminder)
    end
  end

  defp send_reminder(reminder) do
    %{invoice: invoice} = reminder
    client = invoice.client
    from_email = Application.get_env(:auto_my_invoice, :sender_email, "noreply@automyinvoice.app")
    base_url = AutoMyInvoiceWeb.Endpoint.url()

    reminder_with_tracking = Map.put(reminder, :tracking_base_url, base_url)

    email =
      ReminderEmail.build(%{
        reminder: reminder_with_tracking,
        invoice: invoice,
        client: client,
        from_email: from_email
      })

    case Mailer.deliver(email) do
      {:ok, _} ->
        now = DateTime.truncate(DateTime.utc_now(), :second)

        reminder
        |> Reminder.changeset(%{status: "sent", sent_at: now})
        |> Repo.update()

        Phoenix.PubSub.broadcast(
          AutoMyInvoice.PubSub,
          PubSubTopics.user_invoices(invoice.user_id),
          {:invoice_updated, invoice}
        )

        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end
end
