defmodule AutoMyInvoice.Analytics do
  @moduledoc "Analytics Context - collection trends, status distribution, aging, and cashflow forecast"

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Clients.Client

  @doc """
  Monthly collection trends for the last N months.
  Returns a list of maps with month, invoiced total, collected total, and invoice count.
  """
  @spec monthly_collections(binary(), pos_integer()) :: [map()]
  def monthly_collections(user_id, months \\ 6) do
    cutoff = Date.utc_today() |> Date.beginning_of_month() |> Date.shift(month: -(months - 1))

    invoiced_by_month =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: fragment("?::date", i.inserted_at) >= ^cutoff,
        group_by: fragment("to_char(?, 'YYYY-MM')", i.inserted_at),
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", i.inserted_at),
          invoiced: coalesce(sum(coalesce(i.amount_krw, i.amount)), 0),
          count: count(i.id)
        }
      )
      |> Repo.all()
      |> Map.new(fn row -> {row.month, row} end)

    collected_by_month =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status == "paid",
        where: not is_nil(i.paid_at),
        where: fragment("?::date", i.paid_at) >= ^cutoff,
        group_by: fragment("to_char(?, 'YYYY-MM')", i.paid_at),
        select: %{
          month: fragment("to_char(?, 'YYYY-MM')", i.paid_at),
          collected: coalesce(sum(i.paid_amount), 0)
        }
      )
      |> Repo.all()
      |> Map.new(fn row -> {row.month, row.collected} end)

    generate_month_range(cutoff, months)
    |> Enum.map(fn month_str ->
      invoiced_row = Map.get(invoiced_by_month, month_str, %{invoiced: Decimal.new(0), count: 0})
      collected = Map.get(collected_by_month, month_str, Decimal.new(0))

      %{
        month: month_str,
        invoiced: invoiced_row.invoiced,
        collected: collected,
        count: invoiced_row.count
      }
    end)
  end

  @doc """
  Invoice status distribution - count and total amount per status.
  """
  @spec status_distribution(binary()) :: [map()]
  def status_distribution(user_id) do
    from(i in Invoice,
      where: i.user_id == ^user_id,
      group_by: i.status,
      select: %{
        status: i.status,
        count: count(i.id),
        total: coalesce(sum(coalesce(i.amount_krw, i.amount)), 0)
      }
    )
    |> Repo.all()
  end

  @doc """
  Invoice aging buckets for unpaid invoices (sent, overdue, partially_paid).
  Groups by days since due_date into 0-30, 31-60, 61-90, 90+ buckets.
  """
  @spec invoice_aging(binary()) :: map()
  def invoice_aging(user_id) do
    today = Date.utc_today()

    unpaid_invoices =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status in ~w(sent overdue partially_paid),
        where: not is_nil(i.due_date),
        select: %{
          # AMI-90: KRW-equivalent so aging buckets sum correctly across currencies.
          amount: coalesce(i.amount_krw, i.amount),
          paid_amount: i.paid_amount,
          currency: i.currency,
          due_date: i.due_date
        }
      )
      |> Repo.all()

    default_buckets = %{
      "0-30" => %{count: 0, total: Decimal.new(0)},
      "31-60" => %{count: 0, total: Decimal.new(0)},
      "61-90" => %{count: 0, total: Decimal.new(0)},
      "90+" => %{count: 0, total: Decimal.new(0)}
    }

    Enum.reduce(unpaid_invoices, default_buckets, fn invoice, acc ->
      days_overdue = Date.diff(today, invoice.due_date)
      remaining = Decimal.sub(invoice.amount, invoice.paid_amount)
      bucket = aging_bucket(days_overdue)

      Map.update!(acc, bucket, fn current ->
        %{count: current.count + 1, total: Decimal.add(current.total, remaining)}
      end)
    end)
  end

  @doc """
  Cashflow forecast for the next N days.
  For each unpaid invoice, predicts payment date as due_date + client.avg_payment_days.
  Groups by predicted date and sums amounts.
  """
  @spec cashflow_forecast(binary(), pos_integer()) :: [map()]
  def cashflow_forecast(user_id, days \\ 90) do
    today = Date.utc_today()
    horizon = Date.add(today, days)

    unpaid_invoices =
      from(i in Invoice,
        where: i.user_id == ^user_id,
        where: i.status in ~w(sent overdue partially_paid),
        join: c in Client,
        on: c.id == i.client_id,
        select: %{
          # AMI-90: KRW-equivalent so cashflow forecast sums correctly.
          amount: coalesce(i.amount_krw, i.amount),
          paid_amount: i.paid_amount,
          currency: i.currency,
          due_date: i.due_date,
          avg_payment_days: c.avg_payment_days
        }
      )
      |> Repo.all()

    unpaid_invoices
    |> Enum.map(fn inv ->
      offset = inv.avg_payment_days || 0
      predicted_date = Date.add(inv.due_date || today, offset)
      remaining = Decimal.sub(inv.amount, inv.paid_amount)
      {predicted_date, remaining}
    end)
    |> Enum.filter(fn {date, _amount} ->
      Date.compare(date, horizon) != :gt
    end)
    |> Enum.group_by(fn {date, _} -> date end, fn {_, amount} -> amount end)
    |> Enum.map(fn {date, amounts} ->
      %{
        date: date,
        expected_amount: Enum.reduce(amounts, Decimal.new(0), &Decimal.add/2),
        invoice_count: length(amounts)
      }
    end)
    |> Enum.sort_by(& &1.date, Date)
  end

  ## Private

  defp aging_bucket(days) when days <= 30, do: "0-30"
  defp aging_bucket(days) when days <= 60, do: "31-60"
  defp aging_bucket(days) when days <= 90, do: "61-90"
  defp aging_bucket(_days), do: "90+"

  defp generate_month_range(start_date, months) do
    Enum.map(0..(months - 1), fn offset ->
      start_date
      |> Date.shift(month: offset)
      |> Calendar.strftime("%Y-%m")
    end)
  end
end
