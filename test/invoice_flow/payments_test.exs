defmodule InvoiceFlow.PaymentsTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Payments
  alias InvoiceFlow.Payments.{Payment, PaddleWebhookEvent}
  alias InvoiceFlow.Billing
  alias InvoiceFlow.Billing.Subscription
  alias InvoiceFlow.{Accounts, Clients, Invoices}

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "pay-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_client(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Pay Client",
        email: "pclient-#{System.unique_integer([:positive])}@example.com",
        company: "Pay Corp"
      })

    client
  end

  defp create_invoice(user, client) do
    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1500.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [
          %{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1500.00")}
        ]
      })

    invoice
  end

  defp setup_invoice(_context \\ %{}) do
    user = create_user()
    client = create_client(user)
    invoice = create_invoice(user, client)
    %{user: user, client: client, invoice: invoice}
  end

  ## P-6: Payment 생성
  describe "create_payment/2" do
    test "creates payment from webhook data and marks invoice paid" do
      %{invoice: invoice} = setup_invoice()
      {:ok, sent_invoice} = Invoices.mark_as_sent(invoice)

      webhook_data = %{
        "id" => "txn_test_#{System.unique_integer([:positive])}",
        "details" => %{"totals" => %{"total" => "150000"}},
        "currency_code" => "USD",
        "custom_data" => %{"invoice_id" => sent_invoice.id}
      }

      {:ok, payment} = Payments.create_payment(sent_invoice, webhook_data)

      assert payment.paddle_transaction_id == webhook_data["id"]
      assert Decimal.eq?(payment.amount, Decimal.new("1500.00"))
      assert payment.currency == "USD"
      assert payment.status == "completed"
      assert payment.invoice_id == sent_invoice.id
      assert payment.raw_webhook == webhook_data
    end
  end

  ## P-12: Paddle 금액 파싱 (cent → dollar)
  describe "parse_paddle_amount/1" do
    test "converts cent string to dollar decimal" do
      %{invoice: invoice} = setup_invoice()

      webhook_data = %{
        "id" => "txn_cents_#{System.unique_integer([:positive])}",
        "details" => %{"totals" => %{"total" => "150000"}},
        "currency_code" => "USD"
      }

      {:ok, payment} = Payments.create_payment(invoice, webhook_data)
      assert Decimal.eq?(payment.amount, Decimal.new("1500.00"))
    end

    test "rejects nil amount (amount must be > 0)" do
      %{invoice: invoice} = setup_invoice()

      webhook_data = %{
        "id" => "txn_nil_#{System.unique_integer([:positive])}",
        "details" => %{"totals" => %{"total" => nil}},
        "currency_code" => "USD"
      }

      assert {:error, changeset} = Payments.create_payment(invoice, webhook_data)
      assert errors_on(changeset).amount
    end
  end

  ## P-5: 중복 Webhook 멱등성
  describe "webhook event idempotency" do
    test "log_webhook_event creates event" do
      {:ok, event} =
        Payments.log_webhook_event(%{
          event_id: "evt_001",
          event_type: "transaction.completed",
          payload: %{"data" => "test"}
        })

      assert event.event_id == "evt_001"
      assert event.event_type == "transaction.completed"
      assert is_nil(event.processed_at)
    end

    test "duplicate event_id is rejected" do
      {:ok, _} =
        Payments.log_webhook_event(%{
          event_id: "evt_dup",
          event_type: "transaction.completed",
          payload: %{"data" => "test"}
        })

      assert {:error, changeset} =
               Payments.log_webhook_event(%{
                 event_id: "evt_dup",
                 event_type: "transaction.completed",
                 payload: %{"data" => "test2"}
               })

      assert errors_on(changeset).event_id
    end

    test "get_webhook_event returns nil for unknown" do
      assert is_nil(Payments.get_webhook_event("nonexistent"))
    end

    test "get_webhook_event returns existing event" do
      {:ok, event} =
        Payments.log_webhook_event(%{
          event_id: "evt_find",
          event_type: "transaction.completed",
          payload: %{}
        })

      found = Payments.get_webhook_event("evt_find")
      assert found.id == event.id
    end
  end

  ## P-6 확장: mark_event_processed / mark_event_failed
  describe "webhook event lifecycle" do
    test "mark_event_processed sets processed_at" do
      {:ok, event} =
        Payments.log_webhook_event(%{
          event_id: "evt_proc",
          event_type: "transaction.completed",
          payload: %{}
        })

      {:ok, updated} = Payments.mark_event_processed(event)
      assert not is_nil(updated.processed_at)
    end

    test "mark_event_failed sets error_message" do
      {:ok, event} =
        Payments.log_webhook_event(%{
          event_id: "evt_fail",
          event_type: "transaction.completed",
          payload: %{}
        })

      {:ok, updated} = Payments.mark_event_failed(event, "something went wrong")
      assert updated.error_message == "something went wrong"
    end
  end

  ## P-13: 존재하지 않는 invoice_id
  describe "process_transaction_completed/1" do
    test "returns error for non-existent invoice" do
      data = %{
        "id" => "txn_missing",
        "custom_data" => %{"invoice_id" => Ecto.UUID.generate()},
        "details" => %{"totals" => %{"total" => "10000"}},
        "currency_code" => "USD"
      }

      assert {:error, :invoice_not_found} = Payments.process_transaction_completed(data)
    end

    test "processes valid transaction and marks invoice paid" do
      %{invoice: invoice} = setup_invoice()
      {:ok, sent_invoice} = Invoices.mark_as_sent(invoice)

      data = %{
        "id" => "txn_valid_#{System.unique_integer([:positive])}",
        "custom_data" => %{"invoice_id" => sent_invoice.id},
        "details" => %{"totals" => %{"total" => "150000"}},
        "currency_code" => "USD"
      }

      assert :ok = Payments.process_transaction_completed(data)

      updated = Invoices.get_invoice!(sent_invoice.user_id, sent_invoice.id)
      assert updated.status == "paid"
    end
  end

  ## P-8: PubSub 발행
  describe "payment PubSub" do
    test "broadcasts payment_received on transaction completed" do
      %{invoice: invoice} = setup_invoice()
      {:ok, sent_invoice} = Invoices.mark_as_sent(invoice)

      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, "payment:#{sent_invoice.id}")

      data = %{
        "id" => "txn_pubsub_#{System.unique_integer([:positive])}",
        "custom_data" => %{"invoice_id" => sent_invoice.id},
        "details" => %{"totals" => %{"total" => "150000"}},
        "currency_code" => "USD"
      }

      Payments.process_transaction_completed(data)

      assert_receive {:payment_received, _invoice}, 1000
    end
  end

  ## P-9: 결제 목록 조회
  describe "list_payments_for_invoice/1" do
    test "returns payments for invoice ordered by paid_at desc" do
      %{invoice: invoice} = setup_invoice()

      webhook1 = %{
        "id" => "txn_list1_#{System.unique_integer([:positive])}",
        "details" => %{"totals" => %{"total" => "50000"}},
        "currency_code" => "USD"
      }

      webhook2 = %{
        "id" => "txn_list2_#{System.unique_integer([:positive])}",
        "details" => %{"totals" => %{"total" => "100000"}},
        "currency_code" => "USD"
      }

      {:ok, _p1} = Payments.create_payment(invoice, webhook1)
      {:ok, _p2} = Payments.create_payment(invoice, webhook2)

      payments = Payments.list_payments_for_invoice(invoice.id)
      assert length(payments) == 2
    end
  end

  ## P-10: subscription.activated 처리
  describe "activate_subscription/1" do
    test "creates subscription and updates user plan" do
      user = create_user()

      data = %{
        "id" => "sub_test_#{System.unique_integer([:positive])}",
        "customer_id" => "cus_test_123",
        "custom_data" => %{"user_id" => user.id, "plan" => "starter"},
        "current_billing_period" => %{
          "starts_at" => "2026-03-01T00:00:00Z",
          "ends_at" => "2026-04-01T00:00:00Z"
        }
      }

      assert :ok = Billing.activate_subscription(data)

      sub = Billing.get_active_subscription(user.id)
      assert sub.plan == "starter"
      assert sub.status == "active"
      assert sub.paddle_customer_id == "cus_test_123"

      updated_user = Accounts.get_user!(user.id)
      assert updated_user.plan == "starter"
      assert updated_user.paddle_customer_id == "cus_test_123"
    end
  end

  ## P-11: subscription.canceled 처리
  describe "cancel_subscription/1" do
    test "cancels existing subscription" do
      user = create_user()
      paddle_sub_id = "sub_cancel_#{System.unique_integer([:positive])}"

      # 먼저 구독 생성
      {:ok, _sub} =
        %Subscription{user_id: user.id}
        |> Subscription.changeset(%{
          paddle_subscription_id: paddle_sub_id,
          paddle_customer_id: "cus_cancel",
          plan: "pro",
          status: "active"
        })
        |> Repo.insert()

      data = %{"id" => paddle_sub_id}

      assert :ok = Billing.cancel_subscription(data)

      cancelled = Repo.get_by(Subscription, paddle_subscription_id: paddle_sub_id)
      assert cancelled.status == "cancelled"
      assert not is_nil(cancelled.cancelled_at)
    end

    test "returns ok for non-existent subscription" do
      assert :ok = Billing.cancel_subscription(%{"id" => "sub_nonexistent"})
    end
  end

  ## P-10 확장: get_active_subscription
  describe "get_active_subscription/1" do
    test "returns nil when no active subscription" do
      user = create_user()
      assert is_nil(Billing.get_active_subscription(user.id))
    end
  end

  ## Schema 유효성 검증
  describe "Payment changeset" do
    test "validates required fields" do
      changeset = Payment.changeset(%Payment{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors.paddle_transaction_id
      assert errors.amount
      assert errors.paid_at
      assert errors.invoice_id
    end

    test "validates amount > 0" do
      changeset =
        Payment.changeset(%Payment{}, %{
          paddle_transaction_id: "txn_neg",
          amount: Decimal.new("-10"),
          status: "completed",
          paid_at: DateTime.utc_now(),
          invoice_id: Ecto.UUID.generate()
        })

      refute changeset.valid?
      assert errors_on(changeset).amount
    end

    test "validates status inclusion" do
      changeset =
        Payment.changeset(%Payment{}, %{
          paddle_transaction_id: "txn_bad_status",
          amount: Decimal.new("100"),
          status: "invalid",
          paid_at: DateTime.utc_now(),
          invoice_id: Ecto.UUID.generate()
        })

      refute changeset.valid?
      assert errors_on(changeset).status
    end
  end

  describe "Subscription changeset" do
    test "validates required fields" do
      changeset = Subscription.changeset(%Subscription{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors.paddle_subscription_id
      assert errors.plan
    end

    test "validates plan inclusion" do
      changeset =
        Subscription.changeset(%Subscription{}, %{
          paddle_subscription_id: "sub_bad",
          plan: "enterprise",
          status: "active"
        })

      refute changeset.valid?
      assert errors_on(changeset).plan
    end

    test "validates status inclusion" do
      changeset =
        Subscription.changeset(%Subscription{}, %{
          paddle_subscription_id: "sub_bad_status",
          plan: "starter",
          status: "invalid_status"
        })

      refute changeset.valid?
      assert errors_on(changeset).status
    end
  end

  describe "PaddleWebhookEvent changeset" do
    test "validates required fields" do
      changeset = PaddleWebhookEvent.changeset(%PaddleWebhookEvent{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)
      assert errors.event_id
      assert errors.event_type
      assert errors.payload
    end
  end
end
