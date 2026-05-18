defmodule AutoMyInvoice.InvoicesAmountKrwTest do
  @moduledoc """
  AMI-90 — verify amount_krw caches correctly across changesets,
  total_outstanding/1 sums in KRW, and the daily refresh worker backfills
  invoices created before any FX rate was cached.
  """

  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.{Accounts, Clients, FxRates, Invoices, Repo}
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.Workers.FxRateRefreshWorker

  defp register_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email, "fx-#{System.unique_integer([:positive])}@example.com")
    {:ok, user} = Accounts.register_user(%{email: email, password: "ValidPassword123!"})
    user
  end

  defp create_client!(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Acme Co",
        email: "acme-#{System.unique_integer([:positive])}@example.com"
      })

    client
  end

  defp invoice_attrs(client, overrides) do
    Map.merge(
      %{
        amount: Decimal.new(100),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 14),
        client_id: client.id
      },
      overrides
    )
  end

  describe "Invoice changesets — amount_krw caching" do
    test "KRW invoices cache amount_krw equal to amount (rounded to 2dp)" do
      user = register_user!()
      client = create_client!(user)

      {:ok, invoice} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 12_000, currency: "KRW"}))

      assert Decimal.eq?(invoice.amount_krw, Decimal.new("12000.00"))
    end

    test "USD invoices cache amount_krw using the latest USD→KRW rate" do
      user = register_user!()
      client = create_client!(user)
      FxRates.upsert_rate("USD", Decimal.new("1350"))

      {:ok, invoice} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 100, currency: "USD"}))

      assert Decimal.eq?(invoice.amount_krw, Decimal.new("135000.00"))
    end

    test "non-KRW invoice without a cached rate leaves amount_krw nil" do
      user = register_user!()
      client = create_client!(user)

      {:ok, invoice} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 100, currency: "EUR"}))

      assert invoice.amount_krw == nil
    end

    test "update_changeset re-computes amount_krw when amount or currency changes" do
      user = register_user!()
      client = create_client!(user)
      FxRates.upsert_rate("USD", Decimal.new("1350"))

      {:ok, invoice} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 100, currency: "USD"}))

      {:ok, updated} = Invoices.update_invoice(invoice, %{amount: 200})

      # 200 * 1350 = 270_000
      assert Decimal.eq?(updated.amount_krw, Decimal.new("270000.00"))
    end
  end

  describe "Invoices.total_outstanding/1" do
    test "sums sent + overdue invoices in KRW across mixed currencies" do
      user = register_user!()
      client = create_client!(user)
      FxRates.upsert_rate("USD", Decimal.new("1350"))
      FxRates.upsert_rate("EUR", Decimal.new("1480"))

      {:ok, _} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 50_000, currency: "KRW"}))
        |> mark_sent()

      {:ok, _} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 100, currency: "USD"}))
        |> mark_sent()

      {:ok, _} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 50, currency: "EUR"}))
        |> mark_sent()

      {total, _overdue, currency} = Invoices.total_outstanding(user)
      # 50_000 + 100*1350 + 50*1480 = 50_000 + 135_000 + 74_000 = 259_000
      assert Decimal.eq?(total, Decimal.new("259000.00"))
      assert currency == "KRW"
    end

    test "returns 0 when the user has no outstanding invoices" do
      user = register_user!()
      assert {total, 0, "KRW"} = Invoices.total_outstanding(user)
      assert Decimal.eq?(total, Decimal.new(0))
    end
  end

  describe "FxRateRefreshWorker" do
    test "refreshes rates and backfills amount_krw for stale non-KRW invoices" do
      user = register_user!()
      client = create_client!(user)

      # Create a USD invoice BEFORE any FX rate is cached → amount_krw is nil.
      {:ok, invoice} =
        Invoices.create_invoice(user, invoice_attrs(client, %{amount: 100, currency: "USD"}))

      assert invoice.amount_krw == nil

      # Worker fetches stub rates and backfills.
      :ok = FxRateRefreshWorker.perform(%Oban.Job{args: %{}})

      refreshed = Repo.get!(Invoice, invoice.id)
      # Stub rate: USD = 1350
      assert Decimal.eq?(refreshed.amount_krw, Decimal.new("135000.00"))
    end
  end

  defp mark_sent({:ok, invoice}) do
    invoice
    |> Invoice.update_changeset(%{status: "sent"})
    |> Repo.update()
  end
end
