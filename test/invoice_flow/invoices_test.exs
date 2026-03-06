defmodule InvoiceFlow.InvoicesTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Invoices
  alias InvoiceFlow.Invoices.Invoice
  alias InvoiceFlow.Accounts
  alias InvoiceFlow.Clients

  defp create_user(_context \\ %{}) do
    {:ok, user} =
      Accounts.register_user(%{
        email: "inv-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    %{user: user}
  end

  defp create_client(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Test Client",
        email: "client-#{System.unique_integer([:positive])}@example.com",
        company: "Test Corp"
      })

    client
  end

  defp valid_invoice_attrs(client_id) do
    %{
      amount: Decimal.new("1000.00"),
      currency: "USD",
      due_date: Date.add(Date.utc_today(), 30),
      client_id: client_id,
      items: [
        %{description: "Web Design", quantity: Decimal.new(1), unit_price: Decimal.new("500.00")},
        %{description: "Logo Design", quantity: Decimal.new(2), unit_price: Decimal.new("250.00")}
      ]
    }
  end

  describe "create_invoice/2" do
    # I-1: 송장 생성 성공
    test "creates invoice with auto-generated invoice_number and draft status" do
      %{user: user} = create_user()
      client = create_client(user)
      attrs = valid_invoice_attrs(client.id)

      assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(user, attrs)
      assert invoice.invoice_number =~ ~r/^INV-\d{6}-[A-F0-9]{4}$/
      assert invoice.status == "draft"
      assert invoice.amount == Decimal.new("1000.00")
      assert invoice.currency == "USD"
      assert invoice.user_id == user.id
      assert invoice.client_id == client.id
    end

    # I-2: 금액 0 이하 거부
    test "rejects amount less than or equal to zero" do
      %{user: user} = create_user()
      client = create_client(user)
      attrs = valid_invoice_attrs(client.id) |> Map.put(:amount, Decimal.new("-100"))

      assert {:error, changeset} = Invoices.create_invoice(user, attrs)
      assert errors_on(changeset).amount != []
    end

    # I-3: 과거 마감일 거부
    test "rejects past due date" do
      %{user: user} = create_user()
      client = create_client(user)
      attrs = valid_invoice_attrs(client.id) |> Map.put(:due_date, ~D[2020-01-01])

      assert {:error, changeset} = Invoices.create_invoice(user, attrs)
      assert errors_on(changeset).due_date != []
    end

    # I-4: 송장 항목 포함 생성
    test "creates invoice with items and calculates item totals" do
      %{user: user} = create_user()
      client = create_client(user)
      attrs = valid_invoice_attrs(client.id)

      assert {:ok, %Invoice{} = invoice} = Invoices.create_invoice(user, attrs)
      invoice = Repo.preload(invoice, :items)
      assert length(invoice.items) == 2

      web_item = Enum.find(invoice.items, &(&1.description == "Web Design"))
      assert web_item.total == Decimal.new("500.00")

      logo_item = Enum.find(invoice.items, &(&1.description == "Logo Design"))
      assert logo_item.total == Decimal.new("500.00")
    end

    # I-5: Free 플랜 4번째 송장 거부
    test "rejects 4th invoice on free plan" do
      %{user: user} = create_user()
      client = create_client(user)

      for _i <- 1..3 do
        attrs = valid_invoice_attrs(client.id)
        assert {:ok, _} = Invoices.create_invoice(user, attrs)
      end

      attrs = valid_invoice_attrs(client.id)
      assert {:error, :plan_limit} = Invoices.create_invoice(user, attrs)
    end
  end

  describe "status transitions" do
    # I-6: draft → sent 상태 전환
    test "mark_as_sent changes status and records sent_at" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      assert {:ok, %Invoice{} = sent} = Invoices.mark_as_sent(invoice)
      assert sent.status == "sent"
      assert sent.sent_at != nil
    end

    # I-7: sent → paid 상태 전환
    test "mark_as_paid changes status and records paid_at and paid_amount" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, sent} = Invoices.mark_as_sent(invoice)

      assert {:ok, %Invoice{} = paid} = Invoices.mark_as_paid(sent)
      assert paid.status == "paid"
      assert paid.paid_at != nil
      assert paid.paid_amount == paid.amount
    end

    # I-8: paid → sent 전환 거부
    test "rejects invalid status transition paid -> sent" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, sent} = Invoices.mark_as_sent(invoice)
      {:ok, paid} = Invoices.mark_as_paid(sent)

      assert {:error, changeset} = Invoices.mark_as_sent(paid)
      assert errors_on(changeset).status != []
    end

    test "mark_as_overdue changes sent invoice to overdue" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, sent} = Invoices.mark_as_sent(invoice)

      assert {:ok, %Invoice{} = overdue} = Invoices.mark_as_overdue(sent)
      assert overdue.status == "overdue"
    end
  end

  describe "delete_invoice/1" do
    # I-9: draft 송장만 삭제 가능
    test "deletes draft invoice" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      assert {:ok, _} = Invoices.delete_invoice(invoice)
      assert_raise Ecto.NoResultsError, fn ->
        Invoices.get_invoice!(user.id, invoice.id)
      end
    end

    test "rejects deletion of sent invoice" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, sent} = Invoices.mark_as_sent(invoice)

      assert {:error, :cannot_delete_non_draft} = Invoices.delete_invoice(sent)
    end
  end

  describe "list_invoices/2" do
    test "lists user invoices with status filter" do
      %{user: user} = create_user()
      client = create_client(user)

      {:ok, draft} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, inv2} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, _sent} = Invoices.mark_as_sent(inv2)

      drafts = Invoices.list_invoices(user.id, status: "draft")
      assert length(drafts) == 1
      assert hd(drafts).id == draft.id

      all = Invoices.list_invoices(user.id)
      assert length(all) == 2
    end

    test "filters by client_id" do
      %{user: user} = create_user()
      client1 = create_client(user)
      client2 = create_client(user)

      {:ok, _} = Invoices.create_invoice(user, valid_invoice_attrs(client1.id))
      {:ok, _} = Invoices.create_invoice(user, valid_invoice_attrs(client2.id))

      result = Invoices.list_invoices(user.id, client_id: client1.id)
      assert length(result) == 1
    end
  end

  describe "outstanding_summary/1" do
    # I-10: 미수금 집계
    test "calculates outstanding totals" do
      %{user: user} = create_user()
      client = create_client(user)

      {:ok, inv1} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))
      {:ok, _sent1} = Invoices.mark_as_sent(inv1)

      {:ok, inv2} = Invoices.create_invoice(user, valid_invoice_attrs(client.id) |> Map.put(:amount, Decimal.new("2000.00")))
      {:ok, sent2} = Invoices.mark_as_sent(inv2)
      {:ok, _overdue} = Invoices.mark_as_overdue(sent2)

      summary = Invoices.outstanding_summary(user.id)
      assert summary.count == 2
      assert Decimal.eq?(summary.total, Decimal.new("3000.00"))
      assert summary.overdue_count == 1
      assert Decimal.eq?(summary.overdue_total, Decimal.new("2000.00"))
    end
  end

  describe "PubSub" do
    # I-11: 상태 변경 시 PubSub 발행
    test "broadcasts invoice_updated on create" do
      %{user: user} = create_user()
      client = create_client(user)

      topic = InvoiceFlow.PubSubTopics.user_invoices(user.id)
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, topic)

      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      assert_receive {:invoice_updated, ^invoice}
    end

    test "broadcasts invoice_updated on status change" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      topic = InvoiceFlow.PubSubTopics.user_invoices(user.id)
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, topic)

      {:ok, sent} = Invoices.mark_as_sent(invoice)
      assert_receive {:invoice_updated, ^sent}
    end
  end

  describe "get_invoice!/2" do
    test "returns invoice with preloaded associations" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      found = Invoices.get_invoice!(user.id, invoice.id)
      assert found.id == invoice.id
      assert found.client != nil
      assert is_list(found.items)
    end

    test "raises for wrong user_id" do
      %{user: user} = create_user()
      %{user: other} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      assert_raise Ecto.NoResultsError, fn ->
        Invoices.get_invoice!(other.id, invoice.id)
      end
    end
  end

  describe "update_invoice/2" do
    test "updates invoice fields" do
      %{user: user} = create_user()
      client = create_client(user)
      {:ok, invoice} = Invoices.create_invoice(user, valid_invoice_attrs(client.id))

      assert {:ok, updated} = Invoices.update_invoice(invoice, %{notes: "Updated notes"})
      assert updated.notes == "Updated notes"
    end
  end
end
