defmodule AutoMyInvoice.Workers.OverdueNotificationWorker do
  @moduledoc """
  Oban Worker that sends an overdue notification email for a single invoice.

  Receives an invoice_id, loads the invoice + client, builds the email
  via OverdueEmail, delivers via Swoosh, and sets overdue_notified_at.
  """

  use Oban.Worker, queue: :reminders, max_attempts: 5

  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Emails.OverdueEmail
  alias AutoMyInvoice.Mailer
  alias AutoMyInvoice.PubSubTopics

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"invoice_id" => invoice_id}}) do
    invoice =
      Invoice
      |> Repo.get(invoice_id)
      |> maybe_preload()

    case validate_invoice(invoice) do
      :ok -> send_overdue_notification(invoice)
      other -> other
    end
  end

  defp maybe_preload(nil), do: nil
  defp maybe_preload(invoice), do: Repo.preload(invoice, :client)

  defp validate_invoice(nil), do: {:cancel, "invoice not found"}
  defp validate_invoice(%{overdue_notified_at: notified_at}) when not is_nil(notified_at), do: :ok
  defp validate_invoice(%{status: status}) when status != "overdue", do: {:cancel, "invoice not overdue"}

  defp validate_invoice(%{client: %{email: email}}) when is_nil(email) or email == "",
    do: {:cancel, "no client email"}

  defp validate_invoice(%{client: nil}), do: {:cancel, "no client email"}
  defp validate_invoice(_invoice), do: :ok

  defp send_overdue_notification(%{overdue_notified_at: notified_at}) when not is_nil(notified_at) do
    # Already notified — idempotent skip
    :ok
  end

  defp send_overdue_notification(invoice) do
    client = invoice.client
    from_email = Application.get_env(:auto_my_invoice, :sender_email, "noreply@automyinvoice.app")

    email =
      OverdueEmail.build(%{
        invoice: invoice,
        client: client,
        from_email: from_email
      })

    case Mailer.deliver(email) do
      {:ok, _} ->
        now = DateTime.truncate(DateTime.utc_now(), :second)

        invoice
        |> Ecto.Changeset.change(%{overdue_notified_at: now})
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
