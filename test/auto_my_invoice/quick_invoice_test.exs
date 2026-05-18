defmodule AutoMyInvoice.QuickInvoiceTest do
  @moduledoc """
  AMI-89 — instant invoice + QR pay flow.

  Covers Invoices.create_quick_invoice/2 happy path, walk-in client reuse,
  plan-limit error path, and the QR helper.
  """

  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.{Accounts, Clients, Invoices, QR}
  alias AutoMyInvoice.Invoices.Invoice

  defp register_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email, "quick-#{System.unique_integer([:positive])}@example.com")
    {:ok, user} = Accounts.register_user(%{email: email, password: "ValidPassword123!"})
    user
  end

  describe "create_quick_invoice/2" do
    test "creates a sent invoice with the walk-in client and today's due date" do
      user = register_user!()

      {:ok, invoice} =
        Invoices.create_quick_invoice(user, %{amount: 12_000, currency: "KRW"})

      assert invoice.status == "sent"
      assert invoice.sent_at != nil
      assert invoice.currency == "KRW"
      assert Decimal.eq?(invoice.amount, Decimal.new(12_000))
      assert invoice.due_date == Date.utc_today()

      assert %Invoice{client: %Clients.Client{} = client} = Repo.preload(invoice, :client)
      assert client.name == "워크인 고객"
      assert client.email == "walk-in@auto-my-invoice.internal"
    end

    test "reuses the same walk-in client across multiple quick invoices" do
      user = register_user!()

      {:ok, a} = Invoices.create_quick_invoice(user, %{amount: 1000, currency: "KRW"})
      {:ok, b} = Invoices.create_quick_invoice(user, %{amount: 2000, currency: "KRW"})

      assert a.client_id == b.client_id

      # Only ONE walk-in client gets created per user even after N quick
      # invoices — otherwise we'd flood the Clients list with junk rows.
      walk_in_count =
        Clients.list_clients(user.id)
        |> Enum.count(&(&1.email == "walk-in@auto-my-invoice.internal"))

      assert walk_in_count == 1
    end

    test "accepts a non-KRW currency for foreign-market on-the-spot sales" do
      user = register_user!()

      {:ok, invoice} =
        Invoices.create_quick_invoice(user, %{amount: 100, currency: "USD"})

      assert invoice.currency == "USD"
      assert invoice.status == "sent"
    end

    test "returns :plan_limit when the user is past their monthly invoice cap" do
      # New free-tier users cap at 3 invoices/month. Burn through that cap
      # first so the 4th quick invoice trips the limit.
      user = register_user!()

      for _ <- 1..3 do
        {:ok, _} = Invoices.create_quick_invoice(user, %{amount: 1000, currency: "KRW"})
      end

      assert {:error, :plan_limit} =
               Invoices.create_quick_invoice(user, %{amount: 1000, currency: "KRW"})
    end

    test "rejects invalid amount via the regular Invoice changeset" do
      user = register_user!()

      assert {:error, %Ecto.Changeset{}} =
               Invoices.create_quick_invoice(user, %{amount: 0, currency: "KRW"})
    end
  end

  describe "QR helper" do
    test "to_data_url/1 produces a base64 data URL that decodes to PNG bytes" do
      url = "https://auto-my-invoice.com/pay/abc123"
      data_url = QR.to_data_url(url)

      assert "data:image/png;base64," <> b64 = data_url
      assert {:ok, png} = Base.decode64(b64)
      # PNG magic header — guarantees we actually rendered a real PNG, not
      # an HTML error blob or empty string.
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end

    test "to_png/1 produces non-empty PNG bytes for short and long inputs" do
      assert byte_size(QR.to_png("x")) > 100
      assert byte_size(QR.to_png(String.duplicate("a", 200))) > 500
    end
  end
end
