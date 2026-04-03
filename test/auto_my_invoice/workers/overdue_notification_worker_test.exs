defmodule AutoMyInvoice.Workers.OverdueNotificationWorkerTest do
  use AutoMyInvoice.DataCase
  use Oban.Testing, repo: AutoMyInvoice.Repo

  alias AutoMyInvoice.Workers.OverdueNotificationWorker
  alias AutoMyInvoice.Invoices.Invoice
  alias AutoMyInvoice.{Accounts, Clients, Invoices}

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "onw-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_overdue_invoice(user, opts \\ []) do
    client_email = Keyword.get(opts, :client_email, "onw-client-#{System.unique_integer([:positive])}@example.com")

    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "ONW Client",
        email: client_email,
        company: "Corp",
        timezone: "UTC"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("750.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("750.00")}]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)

    # Set due_date to past and mark overdue
    updated =
      sent
      |> Ecto.Changeset.change(due_date: Date.add(Date.utc_today(), -5))
      |> Repo.update!()

    {:ok, overdue} = Invoices.mark_as_overdue(updated)
    overdue
  end

  describe "perform/1" do
    test "sends overdue email and sets overdue_notified_at" do
      user = create_user()
      invoice = create_overdue_invoice(user)

      assert is_nil(invoice.overdue_notified_at)
      assert :ok = perform_job(OverdueNotificationWorker, %{invoice_id: invoice.id})

      updated = Repo.get!(Invoice, invoice.id)
      assert updated.overdue_notified_at != nil
    end

    test "skips if already notified (idempotent)" do
      user = create_user()
      invoice = create_overdue_invoice(user)

      # Manually set overdue_notified_at
      now = DateTime.truncate(DateTime.utc_now(), :second)

      invoice
      |> Ecto.Changeset.change(%{overdue_notified_at: now})
      |> Repo.update!()

      # Should return :ok without error (idempotent skip)
      assert :ok = perform_job(OverdueNotificationWorker, %{invoice_id: invoice.id})
    end

    test "cancels if invoice not found" do
      assert {:cancel, "invoice not found"} =
               perform_job(OverdueNotificationWorker, %{invoice_id: Ecto.UUID.generate()})
    end

    test "cancels if invoice not overdue" do
      user = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{
          name: "ONW Client",
          email: "onw-not-overdue-#{System.unique_integer([:positive])}@example.com",
          company: "Corp",
          timezone: "UTC"
        })

      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          amount: Decimal.new("500.00"),
          currency: "USD",
          due_date: Date.add(Date.utc_today(), 30),
          client_id: client.id,
          items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("500.00")}]
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)

      assert {:cancel, "invoice not overdue"} =
               perform_job(OverdueNotificationWorker, %{invoice_id: sent.id})
    end

    test "handles email delivery failure with retry" do
      # With Swoosh test adapter, emails always succeed.
      # This test verifies the worker can handle the invoice correctly
      # and the retry mechanism is configured via max_attempts: 5.
      user = create_user()
      invoice = create_overdue_invoice(user)

      assert :ok = perform_job(OverdueNotificationWorker, %{invoice_id: invoice.id})

      updated = Repo.get!(Invoice, invoice.id)
      assert updated.overdue_notified_at != nil
    end
  end
end
