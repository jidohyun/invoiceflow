defmodule AutoMyInvoice.TaxInvoicesTest do
  @moduledoc """
  AMI-91 — Korean e-tax invoice issuance.

  Covers the WithholdingCalculator (3.3% on KRW only, floor-rounded),
  TaxInvoices.issue/1 idempotency through the stub client, and the
  send_invoice → tax-invoice hook driven by Invoice.tax_invoice_requested.
  """

  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.{Accounts, Clients, Invoices, Repo, TaxInvoices}
  alias AutoMyInvoice.TaxInvoices.{TaxInvoice, WithholdingCalculator}

  defp register_user!(attrs \\ %{}) do
    email = Map.get(attrs, :email, "tax-#{System.unique_integer([:positive])}@example.com")
    {:ok, user} = Accounts.register_user(%{email: email, password: "ValidPassword123!"})
    user
  end

  defp create_client!(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "K Studio",
        email: "biller-#{System.unique_integer([:positive])}@example.com"
      })

    client
  end

  defp draft_invoice!(user, client, overrides \\ %{}) do
    base = %{
      amount: Decimal.new("1000000"),
      currency: "KRW",
      due_date: Date.add(Date.utc_today(), 14),
      client_id: client.id
    }

    {:ok, invoice} = Invoices.create_invoice(user, Map.merge(base, overrides))
    invoice
  end

  describe "WithholdingCalculator.compute/2" do
    test "applies 3.3% to KRW invoices and floors to the won" do
      assert Decimal.eq?(WithholdingCalculator.compute(1_000_000, "KRW"), Decimal.new(33_000))
      # 100_000 * 0.033 = 3_300
      assert Decimal.eq?(WithholdingCalculator.compute(100_000, "KRW"), Decimal.new(3_300))
      # 123_456 * 0.033 = 4074.048 → floors to 4_074
      assert Decimal.eq?(WithholdingCalculator.compute(123_456, "KRW"), Decimal.new(4_074))
    end

    test "returns zero for non-KRW currencies (Korean withholding does not apply)" do
      assert Decimal.eq?(WithholdingCalculator.compute(1_000, "USD"), Decimal.new(0))
      assert Decimal.eq?(WithholdingCalculator.compute(1_000, "EUR"), Decimal.new(0))
    end
  end

  describe "TaxInvoices.issue/1" do
    test "creates an issued tax_invoice with NTS confirm number + withholding via the stub client" do
      user = register_user!()
      client = create_client!(user)
      invoice = draft_invoice!(user, client)

      assert {:ok, %TaxInvoice{} = ti} = TaxInvoices.issue(invoice)
      assert ti.status == "issued"
      assert is_binary(ti.nts_confirm_no)
      assert String.starts_with?(ti.nts_confirm_no, "STUB-")
      assert ti.issued_at != nil
      assert Decimal.eq?(ti.withholding_tax_amount, Decimal.new(33_000))
      assert ti.raw_response["stub"] == true
    end

    test "is idempotent — re-issuing returns the same row" do
      user = register_user!()
      client = create_client!(user)
      invoice = draft_invoice!(user, client)

      {:ok, first} = TaxInvoices.issue(invoice)
      {:ok, second} = TaxInvoices.issue(invoice)

      assert first.id == second.id
      assert first.nts_confirm_no == second.nts_confirm_no
      # Only one tax_invoice row exists for this invoice.
      assert Repo.aggregate(TaxInvoice, :count, :id) == 1
    end

    test "non-KRW invoices still issue but withhold zero" do
      user = register_user!()
      client = create_client!(user)
      invoice = draft_invoice!(user, client, %{amount: Decimal.new(500), currency: "USD"})

      {:ok, ti} = TaxInvoices.issue(invoice)
      assert ti.status == "issued"
      assert Decimal.eq?(ti.withholding_tax_amount, Decimal.new(0))
    end
  end

  describe "Invoices.send_invoice/1 hook" do
    test "sends + issues a tax invoice when tax_invoice_requested is true" do
      user = register_user!()
      client = create_client!(user)
      invoice = draft_invoice!(user, client, %{tax_invoice_requested: true})

      {:ok, sent} = Invoices.send_invoice(invoice)
      assert sent.status == "sent"
      assert TaxInvoices.get_by_invoice(sent.id) != nil
      assert TaxInvoices.get_by_invoice(sent.id).status == "issued"
    end

    test "does NOT issue a tax invoice when the box is unchecked" do
      user = register_user!()
      client = create_client!(user)
      invoice = draft_invoice!(user, client, %{tax_invoice_requested: false})

      {:ok, sent} = Invoices.send_invoice(invoice)
      assert sent.status == "sent"
      assert TaxInvoices.get_by_invoice(sent.id) == nil
    end
  end
end
