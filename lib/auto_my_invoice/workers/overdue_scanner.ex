defmodule AutoMyInvoice.Workers.OverdueScanner do
  @moduledoc """
  Oban Cron Worker that runs daily at 9am UTC to find overdue invoices
  and enqueue OverdueNotificationWorker jobs.

  Scans for invoices with status "sent" or "partially_paid" whose due_date
  has passed, marks them as overdue, and enqueues notification jobs.
  """

  use Oban.Worker, queue: :default, max_attempts: 1

  require Logger

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Invoices
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Workers.OverdueNotificationWorker

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    today = Date.utc_today()

    overdue_invoices =
      from(i in Invoice,
        where: i.status in ~w(sent partially_paid),
        where: i.due_date < ^today,
        preload: [:client]
      )
      |> Repo.all()

    marked_count =
      overdue_invoices
      |> Enum.map(&mark_and_enqueue/1)
      |> Enum.count(&(&1 == :ok))

    Logger.info("OverdueScanner: marked #{marked_count} invoices as overdue")

    :ok
  end

  defp mark_and_enqueue(invoice) do
    case Invoices.mark_as_overdue(invoice) do
      {:ok, marked_invoice} ->
        try do
          %{invoice_id: marked_invoice.id}
          |> OverdueNotificationWorker.new()
          |> Oban.insert()
        rescue
          e ->
            Logger.error(
              "OverdueScanner: failed to enqueue notification for invoice #{marked_invoice.id}: #{inspect(e)}"
            )
        end

        :ok

      {:error, reason} ->
        Logger.error(
          "OverdueScanner: failed to mark invoice #{invoice.id} as overdue: #{inspect(reason)}"
        )

        :error
    end
  end
end
