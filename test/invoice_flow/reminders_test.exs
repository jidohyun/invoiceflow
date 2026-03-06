defmodule InvoiceFlow.RemindersTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Reminders
  alias InvoiceFlow.Reminders.{Reminder, ReminderTemplate}
  alias InvoiceFlow.Accounts
  alias InvoiceFlow.Clients
  alias InvoiceFlow.Invoices

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "rem-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_sent_invoice(user) do
    {:ok, client} =
      Clients.create_client(user.id, %{
        name: "Client",
        email: "client-#{System.unique_integer([:positive])}@example.com",
        company: "Corp",
        timezone: "Asia/Seoul"
      })

    {:ok, invoice} =
      Invoices.create_invoice(user, %{
        amount: Decimal.new("1000.00"),
        currency: "USD",
        due_date: Date.add(Date.utc_today(), 30),
        client_id: client.id,
        items: [%{description: "Service", quantity: Decimal.new(1), unit_price: Decimal.new("1000.00")}]
      })

    {:ok, sent} = Invoices.mark_as_sent(invoice)
    sent = Repo.preload(sent, :client)
    sent
  end

  defp create_reminder(invoice, step, status \\ "scheduled") do
    scheduled_at = DateTime.add(DateTime.utc_now(), 3600, :second) |> DateTime.truncate(:second)

    {:ok, reminder} =
      %Reminder{invoice_id: invoice.id}
      |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: status})
      |> Repo.insert()

    reminder
  end

  describe "Reminder schema" do
    test "creates reminder with valid attrs" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1)

      assert reminder.step == 1
      assert reminder.status == "scheduled"
      assert reminder.invoice_id == invoice.id
    end

    test "validates step inclusion" do
      changeset = Reminder.changeset(%Reminder{}, %{
        step: 5, scheduled_at: DateTime.utc_now()
      })
      assert errors_on(changeset).step != []
    end

    test "validates status inclusion" do
      changeset = Reminder.changeset(%Reminder{}, %{
        step: 1, scheduled_at: DateTime.utc_now(), status: "invalid"
      })
      assert errors_on(changeset).status != []
    end

    test "validates required fields" do
      changeset = Reminder.changeset(%Reminder{}, %{})
      assert errors_on(changeset).step != []
      assert errors_on(changeset).scheduled_at != []
    end
  end

  describe "ReminderTemplate schema" do
    test "creates template with valid attrs" do
      changeset = ReminderTemplate.changeset(%ReminderTemplate{}, %{
        step: 1,
        tone: "friendly",
        subject_template: "Invoice <%= @invoice_number %>",
        body_template: "Hello <%= @client_name %>"
      })
      assert changeset.valid?
    end

    test "validates tone inclusion" do
      changeset = ReminderTemplate.changeset(%ReminderTemplate{}, %{
        step: 1, tone: "angry",
        subject_template: "test", body_template: "test"
      })
      assert errors_on(changeset).tone != []
    end
  end

  describe "schedule_reminders/1" do
    # R-1: 3개 리마인더 스케줄링
    test "creates 3 reminders for steps 1, 2, 3" do
      user = create_user()
      invoice = create_sent_invoice(user)

      assert {:ok, reminders} = Reminders.schedule_reminders(invoice)
      assert length(reminders) == 3

      steps = Enum.map(reminders, & &1.step) |> Enum.sort()
      assert steps == [1, 2, 3]

      Enum.each(reminders, fn r ->
        assert r.status == "scheduled"
        assert r.scheduled_at != nil
      end)
    end

    # R-2: 스케줄 시각 계산
    test "schedules step 1 at D+1 in client timezone morning" do
      user = create_user()
      invoice = create_sent_invoice(user)
      {:ok, reminders} = Reminders.schedule_reminders(invoice)

      step1 = Enum.find(reminders, &(&1.step == 1))
      step1 = Repo.get!(Reminder, step1.id)

      # D+1 이후여야 함
      expected_min = Date.add(invoice.due_date, 1)
      scheduled_date = DateTime.to_date(step1.scheduled_at)
      assert Date.compare(scheduled_date, expected_min) in [:eq, :gt]
    end

    # R-3: 주말 건너뛰기
    test "skips weekends in scheduling" do
      # skip_weekends는 private이므로 간접 테스트
      # 토요일 마감일 → step1 D+1 = 일요일 → 월요일로 이동
      user = create_user()

      {:ok, client} =
        Clients.create_client(user.id, %{
          name: "Weekend Client",
          email: "wk-#{System.unique_integer([:positive])}@example.com",
          company: "Corp",
          timezone: "UTC"
        })

      # 다가오는 금요일 찾기
      today = Date.utc_today()
      days_until_friday = rem(5 - Date.day_of_week(today) + 7, 7)
      days_until_friday = if days_until_friday == 0, do: 7, else: days_until_friday
      next_friday = Date.add(today, days_until_friday)

      {:ok, invoice} =
        Invoices.create_invoice(user, %{
          amount: Decimal.new("500.00"),
          currency: "USD",
          due_date: next_friday,
          client_id: client.id,
          items: [%{description: "Test", quantity: Decimal.new(1), unit_price: Decimal.new("500.00")}]
        })

      {:ok, sent} = Invoices.mark_as_sent(invoice)
      sent = Repo.preload(sent, :client)

      {:ok, reminders} = Reminders.schedule_reminders(sent)

      # step1 D+1 = 토요일 → 월요일(day_of_week 1)
      step1 = Enum.find(reminders, &(&1.step == 1))
      step1 = Repo.get!(Reminder, step1.id)
      day = Date.day_of_week(DateTime.to_date(step1.scheduled_at))
      assert day in 1..5, "Scheduled day should be a weekday, got #{day}"
    end
  end

  describe "cancel_pending_reminders/1" do
    # R-4: 결제 완료 시 리마인더 취소
    test "cancels all pending/scheduled reminders for invoice" do
      user = create_user()
      invoice = create_sent_invoice(user)

      _r1 = create_reminder(invoice, 1, "scheduled")
      _r2 = create_reminder(invoice, 2, "pending")
      _r3 = create_reminder(invoice, 3, "sent")  # 이미 발송됨 → 취소 안됨

      {cancelled_count, nil} = Reminders.cancel_pending_reminders(invoice.id)
      assert cancelled_count == 2

      reminders = Reminders.list_reminders_for_invoice(invoice.id)
      statuses = Enum.map(reminders, & &1.status)
      assert "cancelled" in statuses
      assert "sent" in statuses  # 발송된 것은 그대로
    end
  end

  describe "record_open/1" do
    # R-9: 오픈 추적
    test "increments open count and records first opened_at" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "sent")

      {:ok, opened} = Reminders.record_open(reminder.id)
      assert opened.open_count == 1
      assert opened.opened_at != nil

      first_opened_at = opened.opened_at
      {:ok, opened_again} = Reminders.record_open(reminder.id)
      assert opened_again.open_count == 2
      assert opened_again.opened_at == first_opened_at  # 최초 시각 유지
    end
  end

  describe "record_click/1" do
    # R-10: 클릭 추적
    test "increments click count and records first clicked_at" do
      user = create_user()
      invoice = create_sent_invoice(user)
      reminder = create_reminder(invoice, 1, "sent")

      {:ok, clicked} = Reminders.record_click(reminder.id)
      assert clicked.click_count == 1
      assert clicked.clicked_at != nil

      first_clicked_at = clicked.clicked_at
      {:ok, clicked_again} = Reminders.record_click(reminder.id)
      assert clicked_again.click_count == 2
      assert clicked_again.clicked_at == first_clicked_at
    end
  end

  describe "list_reminders_for_invoice/1" do
    test "returns reminders ordered by step" do
      user = create_user()
      invoice = create_sent_invoice(user)

      create_reminder(invoice, 3)
      create_reminder(invoice, 1)
      create_reminder(invoice, 2)

      reminders = Reminders.list_reminders_for_invoice(invoice.id)
      steps = Enum.map(reminders, & &1.step)
      assert steps == [1, 2, 3]
    end
  end
end
