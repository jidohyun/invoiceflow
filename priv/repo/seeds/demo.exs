# Demo seed script for AutoMyInvoice
#
# Run with: mix run priv/repo/seeds/demo.exs
#
# Creates a demo user, 3 clients, 20+ invoices, payments, and reminders.

alias AutoMyInvoice.Repo
alias AutoMyInvoice.Accounts
alias AutoMyInvoice.Accounts.User
alias AutoMyInvoice.Clients
alias AutoMyInvoice.Clients.Client
alias AutoMyInvoice.Invoices.Invoice
alias AutoMyInvoice.Reminders.Reminder

# ── Demo User ──────────────────────────────────────────────────────────

demo_email = "demo@automyinvoice.app"

user =
  case Accounts.get_user_by_email(demo_email) do
    %User{} = existing ->
      IO.puts("Demo user already exists: #{existing.id}")
      existing

    nil ->
      {:ok, new_user} =
        Accounts.register_user(%{
          email: demo_email,
          password: "demo123456"
        })

      IO.puts("Created demo user: #{new_user.id}")
      new_user
  end

# ── Clients ────────────────────────────────────────────────────────────

client_attrs = [
  %{
    name: "김민수 디자인",
    email: "minsu@kimdesign.kr",
    company: "김민수 디자인 스튜디오",
    timezone: "Asia/Seoul",
    phone: "+82-10-1234-5678"
  },
  %{
    name: "박미디어 그룹",
    email: "billing@parkmedia.kr",
    company: "주식회사 박미디어",
    timezone: "Asia/Seoul",
    phone: "+82-2-555-0100"
  },
  %{
    name: "글로벌테크",
    email: "accounts@globaltech.kr",
    company: "글로벌테크 주식회사",
    timezone: "Asia/Seoul",
    phone: "+82-31-7946-0958"
  }
]

clients =
  Enum.map(client_attrs, fn attrs ->
    case Clients.get_client_by_email(user.id, attrs.email) do
      %Client{} = existing ->
        IO.puts("Client already exists: #{existing.name}")
        existing

      nil ->
        {:ok, client} = Clients.create_client(user.id, attrs)
        IO.puts("Created client: #{client.name}")
        client
    end
  end)

[client_a, client_b, client_c] = clients

# ── Helper Functions ───────────────────────────────────────────────────

dt = fn year, month, day ->
  {:ok, naive} = NaiveDateTime.new(year, month, day, 12, 0, 0)
  {:ok, result} = DateTime.from_naive(naive, "Etc/UTC")
  result
end

d = fn year, month, day ->
  Date.new!(year, month, day)
end

# ── Invoices ───────────────────────────────────────────────────────────
#
# Client A (김민수 디자인): 성실 결제자 - 대부분 기한 내 결제
# Client B (박미디어 그룹): 종종 지연 결제
# Client C (글로벌테크): 자주 연체 또는 미납

now = DateTime.truncate(DateTime.utc_now(), :second)

invoice_specs = [
  # ── Client A: 기한 내 결제 완료 ──
  %{
    client_id: client_a.id, amount: Decimal.new("1_200_000"), currency: "KRW",
    invoice_number: "INV-202601-A001", status: "paid",
    due_date: d.(2026, 1, 20), sent_at: dt.(2026, 1, 5), paid_at: dt.(2026, 1, 18),
    paid_amount: Decimal.new("1_200_000")
  },
  %{
    client_id: client_a.id, amount: Decimal.new("2_500_000"), currency: "KRW",
    invoice_number: "INV-202601-A002", status: "paid",
    due_date: d.(2026, 1, 31), sent_at: dt.(2026, 1, 15), paid_at: dt.(2026, 1, 29),
    paid_amount: Decimal.new("2_500_000")
  },
  %{
    client_id: client_a.id, amount: Decimal.new("800_000"), currency: "KRW",
    invoice_number: "INV-202602-A003", status: "paid",
    due_date: d.(2026, 2, 15), sent_at: dt.(2026, 2, 1), paid_at: dt.(2026, 2, 13),
    paid_amount: Decimal.new("800_000")
  },
  %{
    client_id: client_a.id, amount: Decimal.new("3_000_000"), currency: "KRW",
    invoice_number: "INV-202602-A004", status: "paid",
    due_date: d.(2026, 2, 28), sent_at: dt.(2026, 2, 10), paid_at: dt.(2026, 2, 26),
    paid_amount: Decimal.new("3_000_000")
  },
  %{
    client_id: client_a.id, amount: Decimal.new("1_500_000"), currency: "KRW",
    invoice_number: "INV-202603-A005", status: "sent",
    due_date: d.(2026, 4, 10), sent_at: dt.(2026, 3, 25),
    paid_at: nil, paid_amount: Decimal.new("0")
  },

  # ── Client B: 지연 결제 혼재 ──
  %{
    client_id: client_b.id, amount: Decimal.new("4_000_000"), currency: "KRW",
    invoice_number: "INV-202601-B001", status: "paid",
    due_date: d.(2026, 1, 15), sent_at: dt.(2026, 1, 2), paid_at: dt.(2026, 1, 25),
    paid_amount: Decimal.new("4_000_000")
  },
  %{
    client_id: client_b.id, amount: Decimal.new("1_800_000"), currency: "KRW",
    invoice_number: "INV-202601-B002", status: "paid",
    due_date: d.(2026, 1, 31), sent_at: dt.(2026, 1, 10), paid_at: dt.(2026, 2, 7),
    paid_amount: Decimal.new("1_800_000")
  },
  %{
    client_id: client_b.id, amount: Decimal.new("2_200_000"), currency: "KRW",
    invoice_number: "INV-202602-B003", status: "paid",
    due_date: d.(2026, 2, 20), sent_at: dt.(2026, 2, 5), paid_at: dt.(2026, 2, 27),
    paid_amount: Decimal.new("2_200_000")
  },
  %{
    client_id: client_b.id, amount: Decimal.new("3_500_000"), currency: "KRW",
    invoice_number: "INV-202603-B004", status: "partially_paid",
    due_date: d.(2026, 3, 15), sent_at: dt.(2026, 3, 1),
    paid_at: nil, paid_amount: Decimal.new("1_500_000")
  },
  %{
    client_id: client_b.id, amount: Decimal.new("5_000_000"), currency: "KRW",
    invoice_number: "INV-202603-B005", status: "sent",
    due_date: d.(2026, 4, 5), sent_at: dt.(2026, 3, 20),
    paid_at: nil, paid_amount: Decimal.new("0")
  },
  %{
    client_id: client_b.id, amount: Decimal.new("950_000"), currency: "KRW",
    invoice_number: "INV-202603-B006", status: "draft",
    due_date: d.(2026, 4, 30), sent_at: nil,
    paid_at: nil, paid_amount: Decimal.new("0")
  },

  # ── Client C: 자주 연체 ──
  %{
    client_id: client_c.id, amount: Decimal.new("3_200_000"), currency: "KRW",
    invoice_number: "INV-202601-C001", status: "paid",
    due_date: d.(2026, 1, 10), sent_at: dt.(2026, 1, 1), paid_at: dt.(2026, 2, 2),
    paid_amount: Decimal.new("3_200_000")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("1_500_000"), currency: "KRW",
    invoice_number: "INV-202601-C002", status: "paid",
    due_date: d.(2026, 1, 25), sent_at: dt.(2026, 1, 8), paid_at: dt.(2026, 2, 15),
    paid_amount: Decimal.new("1_500_000")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("4_500_000"), currency: "KRW",
    invoice_number: "INV-202602-C003", status: "paid",
    due_date: d.(2026, 2, 10), sent_at: dt.(2026, 1, 25), paid_at: dt.(2026, 3, 5),
    paid_amount: Decimal.new("4_500_000")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("2_800_000"), currency: "KRW",
    invoice_number: "INV-202602-C004", status: "overdue",
    due_date: d.(2026, 2, 28), sent_at: dt.(2026, 2, 10),
    paid_at: nil, paid_amount: Decimal.new("0")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("1_900_000"), currency: "KRW",
    invoice_number: "INV-202603-C005", status: "overdue",
    due_date: d.(2026, 3, 10), sent_at: dt.(2026, 2, 25),
    paid_at: nil, paid_amount: Decimal.new("0")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("3_700_000"), currency: "KRW",
    invoice_number: "INV-202603-C006", status: "overdue",
    due_date: d.(2026, 3, 20), sent_at: dt.(2026, 3, 5),
    paid_at: nil, paid_amount: Decimal.new("0")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("2_100_000"), currency: "KRW",
    invoice_number: "INV-202603-C007", status: "partially_paid",
    due_date: d.(2026, 3, 25), sent_at: dt.(2026, 3, 10),
    paid_at: nil, paid_amount: Decimal.new("700_000")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("600_000"), currency: "KRW",
    invoice_number: "INV-202603-C008", status: "sent",
    due_date: d.(2026, 4, 15), sent_at: dt.(2026, 3, 28),
    paid_at: nil, paid_amount: Decimal.new("0")
  },
  %{
    client_id: client_c.id, amount: Decimal.new("1_100_000"), currency: "KRW",
    invoice_number: "INV-202603-C009", status: "draft",
    due_date: d.(2026, 4, 30), sent_at: nil,
    paid_at: nil, paid_amount: Decimal.new("0")
  },
]

# Check if invoices already seeded (by checking for first invoice_number)
existing_check =
  Repo.get_by(Invoice, invoice_number: "INV-202601-A001", user_id: user.id)

invoices =
  if existing_check do
    IO.puts("Invoices already seeded, skipping...")

    Enum.map(invoice_specs, fn spec ->
      Repo.get_by!(Invoice, invoice_number: spec.invoice_number, user_id: user.id)
    end)
  else
    Enum.map(invoice_specs, fn spec ->
      invoice =
        %Invoice{user_id: user.id}
        |> Ecto.Changeset.change(
          invoice_number: spec.invoice_number,
          amount: spec.amount,
          currency: spec.currency,
          due_date: spec.due_date,
          status: spec.status,
          client_id: spec.client_id,
          sent_at: spec.sent_at,
          paid_at: spec.paid_at,
          paid_amount: spec.paid_amount,
          inserted_at: spec.sent_at || now,
          updated_at: spec.paid_at || spec.sent_at || now
        )
        |> Repo.insert!()

      IO.puts("Created invoice: #{invoice.invoice_number} [#{invoice.status}]")
      invoice
    end)
  end

# ── Reminders ──────────────────────────────────────────────────────────
#
# Create reminders for sent/overdue invoices with realistic tracking data

# Find invoices that should have reminders (sent, overdue, partially_paid)
reminder_invoices =
  invoices
  |> Enum.filter(fn inv -> inv.status in ["sent", "overdue", "partially_paid"] end)

unless existing_check do
  Enum.each(reminder_invoices, fn invoice ->
    # Step 1 reminder (sent 1 day after due date)
    r1_scheduled = DateTime.add(DateTime.new!(invoice.due_date, ~T[09:00:00], "Etc/UTC"), 86_400)
    r1_sent_at = DateTime.add(r1_scheduled, 60)

    r1 =
      %Reminder{invoice_id: invoice.id}
      |> Ecto.Changeset.change(
        step: 1,
        scheduled_at: r1_scheduled,
        sent_at: r1_sent_at,
        status: "sent",
        open_count: Enum.random(0..3),
        opened_at: if(Enum.random(0..1) == 1, do: DateTime.add(r1_sent_at, 3_600)),
        click_count: Enum.random(0..1),
        clicked_at: if(Enum.random(0..2) == 2, do: DateTime.add(r1_sent_at, 7_200)),
        inserted_at: r1_scheduled,
        updated_at: r1_sent_at
      )
      |> Repo.insert!()

    IO.puts("  Reminder step=1 for #{invoice.invoice_number}")

    # Step 2 reminder (7 days after due date) - only for overdue invoices
    if invoice.status == "overdue" do
      r2_scheduled = DateTime.add(DateTime.new!(invoice.due_date, ~T[10:00:00], "Etc/UTC"), 7 * 86_400)
      r2_sent_at = DateTime.add(r2_scheduled, 120)

      %Reminder{invoice_id: invoice.id}
      |> Ecto.Changeset.change(
        step: 2,
        scheduled_at: r2_scheduled,
        sent_at: r2_sent_at,
        status: "sent",
        open_count: Enum.random(0..2),
        opened_at: if(Enum.random(0..1) == 1, do: DateTime.add(r2_sent_at, 5_400)),
        click_count: 0,
        clicked_at: nil,
        inserted_at: r2_scheduled,
        updated_at: r2_sent_at
      )
      |> Repo.insert!()

      IO.puts("  Reminder step=2 for #{invoice.invoice_number}")

      # Step 3 (14 days after due date) - scheduled but not yet sent for some
      r3_scheduled = DateTime.add(DateTime.new!(invoice.due_date, ~T[09:30:00], "Etc/UTC"), 14 * 86_400)

      %Reminder{invoice_id: invoice.id}
      |> Ecto.Changeset.change(
        step: 3,
        scheduled_at: r3_scheduled,
        status: "scheduled",
        open_count: 0,
        click_count: 0,
        inserted_at: r3_scheduled,
        updated_at: r3_scheduled
      )
      |> Repo.insert!()

      IO.puts("  Reminder step=3 (scheduled) for #{invoice.invoice_number}")
    end
  end)

  IO.puts("\nReminders created.")
end

# ── Recalculate Client Stats ──────────────────────────────────────────

Enum.each(clients, fn client ->
  {:ok, updated} = Clients.recalculate_stats(client.id)

  IO.puts(
    "Stats for #{updated.name}: " <>
      "total_invoiced=#{updated.total_invoiced}, " <>
      "total_paid=#{updated.total_paid}, " <>
      "avg_payment_days=#{updated.avg_payment_days || "N/A"}"
  )
end)

IO.puts("\nDemo seed complete!")
IO.puts("Login: #{demo_email} / demo123456")
