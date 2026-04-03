defmodule AutoMyInvoice.Workers.OverdueScannerTest do
  use AutoMyInvoice.DataCase
  use Oban.Testing, repo: AutoMyInvoice.Repo

  alias AutoMyInvoice.Workers.OverdueScanner
  alias AutoMyInvoice.{Accounts, Clients, Invoices}
  alias AutoMyInvoice.Invoices.Invoice

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "os-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_client(user, opts \\ []) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: Keyword.get(opts, :name, "OS Client"),
        email: "os-client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: Keyword.get(opts, :timezone, "UTC")
      })

    client
  end

  defp create_invoice_with_status(user, client, status, due_date) do
    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1000.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}]
      })

    # Move to sent first (required transition from draft)
    {:ok, sent} = Invoices.mark_as_sent(invoice)

    # Then transition to the desired status
    case status do
      "sent" ->
        # Override due_date directly to simulate past due
        sent
        |> Ecto.Changeset.change(due_date: due_date)
        |> Repo.update!()

      "partially_paid" ->
        {:ok, partial} = Invoices.record_payment(sent, %{"amount" => "100.00"})

        partial
        |> Ecto.Changeset.change(due_date: due_date)
        |> Repo.update!()

      "overdue" ->
        updated =
          sent
          |> Ecto.Changeset.change(due_date: due_date)
          |> Repo.update!()

        {:ok, overdue} = Invoices.mark_as_overdue(updated)
        overdue

      "paid" ->
        {:ok, paid} = Invoices.mark_as_paid(sent)

        paid
        |> Ecto.Changeset.change(due_date: due_date)
        |> Repo.update!()
    end
  end

  describe "perform/1" do
    test "marks sent invoices past due_date as overdue" do
      user = create_user()
      client = create_client(user)
      past_due = Date.add(Date.utc_today(), -3)
      invoice = create_invoice_with_status(user, client, "sent", past_due)

      assert :ok = perform_job(OverdueScanner, %{})

      updated = Repo.get!(Invoice, invoice.id)
      assert updated.status == "overdue"
    end

    test "marks partially_paid invoices past due_date as overdue" do
      user = create_user()
      client = create_client(user)
      past_due = Date.add(Date.utc_today(), -5)
      invoice = create_invoice_with_status(user, client, "partially_paid", past_due)

      assert :ok = perform_job(OverdueScanner, %{})

      updated = Repo.get!(Invoice, invoice.id)
      assert updated.status == "overdue"
    end

    test "does not mark already overdue invoices" do
      user = create_user()
      client = create_client(user)
      past_due = Date.add(Date.utc_today(), -3)
      invoice = create_invoice_with_status(user, client, "overdue", past_due)

      assert invoice.status == "overdue"
      assert :ok = perform_job(OverdueScanner, %{})

      # Status should remain overdue (not re-processed)
      updated = Repo.get!(Invoice, invoice.id)
      assert updated.status == "overdue"
    end

    test "does not mark paid invoices" do
      user = create_user()
      client = create_client(user)
      past_due = Date.add(Date.utc_today(), -3)
      invoice = create_invoice_with_status(user, client, "paid", past_due)

      assert :ok = perform_job(OverdueScanner, %{})

      updated = Repo.get!(Invoice, invoice.id)
      assert updated.status == "paid"
    end

    test "enqueues OverdueNotificationWorker for each marked invoice" do
      user = create_user()
      client = create_client(user)
      past_due = Date.add(Date.utc_today(), -3)
      invoice = create_invoice_with_status(user, client, "sent", past_due)

      assert :ok = perform_job(OverdueScanner, %{})

      # With Oban testing: :inline, the worker is executed inline.
      # Verify the invoice was marked overdue (which implies the worker chain ran).
      updated = Repo.get!(Invoice, invoice.id)
      assert updated.status == "overdue"
      # The notification worker should have set overdue_notified_at
      assert updated.overdue_notified_at != nil
    end

    test "returns :ok with no overdue invoices" do
      assert :ok = perform_job(OverdueScanner, %{})
    end
  end
end
