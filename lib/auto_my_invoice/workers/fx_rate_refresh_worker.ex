defmodule AutoMyInvoice.Workers.FxRateRefreshWorker do
  @moduledoc """
  Pulls the latest USD/EUR/JPY/GBP → KRW quotes and backfills
  `invoices.amount_krw` for any non-KRW invoice that's still missing one.

  Runs daily via Oban cron. Idempotent — repeated runs just refresh the
  rate row and re-cast amount_krw on every non-KRW invoice.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query
  require Logger

  alias AutoMyInvoice.{FxRates, Repo}
  alias AutoMyInvoice.Invoices.Invoice

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    refreshed = FxRates.refresh!()
    Logger.info("FxRateRefreshWorker refreshed=#{Enum.join(refreshed, ",")}")

    backfilled = backfill_amount_krw(refreshed)
    Logger.info("FxRateRefreshWorker backfilled_invoices=#{backfilled}")

    :ok
  end

  defp backfill_amount_krw([]), do: 0

  defp backfill_amount_krw(refreshed) do
    Invoice
    |> where([i], i.currency in ^refreshed)
    |> Repo.all()
    |> Enum.reduce(0, fn invoice, acc ->
      case FxRates.to_krw(invoice.amount, invoice.currency) do
        {:ok, krw} ->
          invoice
          |> Ecto.Changeset.change(amount_krw: krw)
          |> Repo.update()

          acc + 1

        _ ->
          acc
      end
    end)
  end
end
