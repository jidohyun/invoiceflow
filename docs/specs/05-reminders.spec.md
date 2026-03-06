# 05 - Reminders Spec

> **구현 완료** | 2026-03-04 | 13 tests 통과 (92 tests 전체 기준)
> - Reminder 스키마 (3단계 step, 상태 관리, 추적 필드)
> - ReminderTemplate 스키마 (톤 검증, step 검증)
> - Reminders Context (스케줄링, 주말 스킵, 취소, 오픈/클릭 추적)
> - tzdata 의존성 추가하여 클라이언트 타임존 기반 발송 시각 계산

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | 3단계 AI 이메일 리마인더 스케줄링, 발송, 추적 |
| **Context** | `InvoiceFlow.Reminders` |
| **의존성** | 03-invoices (Invoice), 02-clients (Client), 01-accounts (User) |
| **예상 기간** | Week 5~7 |

---

## 1. Ecto Schemas

### 1.1 Reminder

```elixir
defmodule InvoiceFlow.Reminders.Reminder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @steps [1, 2, 3]
  @statuses ~w(pending scheduled sent cancelled failed)

  schema "reminders" do
    field :step, :integer                  # 1 (D+1), 2 (D+7), 3 (D+14)
    field :scheduled_at, :utc_datetime     # 발송 예정 시각
    field :sent_at, :utc_datetime
    field :status, :string, default: "pending"

    # 이메일 콘텐츠
    field :email_subject, :string
    field :email_body, :string             # HTML

    # 추적
    field :opened_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :open_count, :integer, default: 0
    field :click_count, :integer, default: 0

    # Oban 연결
    field :oban_job_id, :integer

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:step, :scheduled_at, :sent_at, :status,
                     :email_subject, :email_body,
                     :opened_at, :clicked_at, :open_count, :click_count,
                     :oban_job_id])
    |> validate_required([:step, :scheduled_at])
    |> validate_inclusion(:step, @steps)
    |> validate_inclusion(:status, @statuses)
  end

  def tracking_changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:opened_at, :clicked_at, :open_count, :click_count])
  end
end
```

### 1.2 ReminderTemplate

```elixir
defmodule InvoiceFlow.Reminders.ReminderTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reminder_templates" do
    field :step, :integer
    field :tone, :string                   # friendly | gentle | firm
    field :subject_template, :string       # EEx 템플릿
    field :body_template, :string          # EEx 템플릿 (HTML)
    field :is_default, :boolean, default: false

    belongs_to :user, InvoiceFlow.Accounts.User  # nil이면 시스템 기본

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:step, :tone, :subject_template, :body_template, :is_default, :user_id])
    |> validate_required([:step, :tone, :subject_template, :body_template])
    |> validate_inclusion(:step, [1, 2, 3])
    |> validate_inclusion(:tone, ~w(friendly gentle firm))
  end
end
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreateReminders do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :step, :integer, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :sent_at, :utc_datetime
      add :status, :string, default: "pending", null: false

      add :email_subject, :text
      add :email_body, :text

      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :open_count, :integer, default: 0
      add :click_count, :integer, default: 0

      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:reminders, [:invoice_id])
    create index(:reminders, [:status])
    create index(:reminders, [:scheduled_at])
    create unique_index(:reminders, [:invoice_id, :step])

    create table(:reminder_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      add :step, :integer, null: false
      add :tone, :string, null: false
      add :subject_template, :text, null: false
      add :body_template, :text, null: false
      add :is_default, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:reminder_templates, [:user_id])
    create index(:reminder_templates, [:step, :is_default])
  end
end
```

---

## 3. 3단계 리마인더 로직

### 3.1 스케줄 규칙

| 단계 | 발송 시점 | 톤 | 내용 |
|------|-----------|-----|------|
| **Step 1** | 마감일 + 1일 | friendly | 감사 인사 + 결제 확인 요청 |
| **Step 2** | 마감일 + 7일 | gentle | 부드러운 독촉, 도움 제안 |
| **Step 3** | 마감일 + 14일 | firm | 최종 경고, 연체료 언급 가능 |

### 3.2 발송 시간 최적화

```
수신자 타임존 기준 오전 9시~11시 사이에 발송
├─ client.timezone 확인
├─ 해당 타임존의 다음 영업일 09:00 ~ 11:00 중 랜덤 시각
└─ 주말/공휴일이면 다음 월요일로 이동
```

---

## 4. Context Functions

```elixir
defmodule InvoiceFlow.Reminders do
  @moduledoc "리마인더 스케줄링, 발송, 추적 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Reminders.{Reminder, ReminderTemplate}
  alias InvoiceFlow.Workers.ReminderWorker

  @step_offsets %{1 => 1, 2 => 7, 3 => 14}

  ## 스케줄링

  @spec schedule_reminders(Invoice.t()) :: {:ok, [Reminder.t()]}
  def schedule_reminders(%{id: invoice_id, due_date: due_date, client: client}) do
    reminders =
      for {step, offset} <- @step_offsets do
        scheduled_at = calculate_send_time(due_date, offset, client.timezone)

        {:ok, reminder} =
          %Reminder{invoice_id: invoice_id}
          |> Reminder.changeset(%{step: step, scheduled_at: scheduled_at, status: "scheduled"})
          |> Repo.insert()

        # Oban 작업 예약
        {:ok, oban_job} =
          %{reminder_id: reminder.id}
          |> ReminderWorker.new(queue: :reminders, scheduled_at: scheduled_at)
          |> Oban.insert()

        {:ok, _} =
          reminder
          |> Reminder.changeset(%{oban_job_id: oban_job.id})
          |> Repo.update()

        reminder
      end

    {:ok, reminders}
  end

  ## 취소

  @spec cancel_pending_reminders(binary()) :: {integer(), nil}
  def cancel_pending_reminders(invoice_id) do
    pending_reminders =
      from(r in Reminder,
        where: r.invoice_id == ^invoice_id,
        where: r.status in ~w(pending scheduled)
      )
      |> Repo.all()

    Enum.each(pending_reminders, fn reminder ->
      if reminder.oban_job_id do
        Oban.cancel_job(reminder.oban_job_id)
      end

      reminder
      |> Reminder.changeset(%{status: "cancelled"})
      |> Repo.update()
    end)

    {length(pending_reminders), nil}
  end

  ## 이메일 콘텐츠 생성

  @spec generate_email_content(Reminder.t()) :: {:ok, %{subject: String.t(), body: String.t()}}
  def generate_email_content(%Reminder{} = reminder) do
    reminder = Repo.preload(reminder, invoice: [:client, :user])
    template = get_template(reminder.step, reminder.invoice.user_id)

    assigns = %{
      client_name: reminder.invoice.client.name,
      invoice_number: reminder.invoice.invoice_number,
      amount: reminder.invoice.amount,
      currency: reminder.invoice.currency,
      due_date: reminder.invoice.due_date,
      days_overdue: Date.diff(Date.utc_today(), reminder.invoice.due_date),
      payment_link: reminder.invoice.paddle_payment_link,
      company_name: reminder.invoice.user.company_name
    }

    subject = EEx.eval_string(template.subject_template, assigns: assigns)
    body = EEx.eval_string(template.body_template, assigns: assigns)

    {:ok, %{subject: subject, body: body}}
  end

  ## 이메일 발송

  @spec send_reminder(Reminder.t()) :: {:ok, Reminder.t()} | {:error, term()}
  def send_reminder(%Reminder{} = reminder) do
    reminder = Repo.preload(reminder, invoice: [:client, :user])

    with {:ok, %{subject: subject, body: body}} <- generate_email_content(reminder),
         {:ok, _email} <- deliver_email(reminder, subject, body) do
      reminder
      |> Reminder.changeset(%{
        status: "sent",
        sent_at: DateTime.utc_now(),
        email_subject: subject,
        email_body: body
      })
      |> Repo.update()
    else
      {:error, reason} ->
        reminder
        |> Reminder.changeset(%{status: "failed"})
        |> Repo.update()

        {:error, reason}
    end
  end

  ## 추적

  @spec record_open(binary()) :: {:ok, Reminder.t()}
  def record_open(reminder_id) do
    reminder = Repo.get!(Reminder, reminder_id)

    attrs = %{
      open_count: reminder.open_count + 1,
      opened_at: reminder.opened_at || DateTime.utc_now()
    }

    reminder
    |> Reminder.tracking_changeset(attrs)
    |> Repo.update()
  end

  @spec record_click(binary()) :: {:ok, Reminder.t()}
  def record_click(reminder_id) do
    reminder = Repo.get!(Reminder, reminder_id)

    attrs = %{
      click_count: reminder.click_count + 1,
      clicked_at: reminder.clicked_at || DateTime.utc_now()
    }

    reminder
    |> Reminder.tracking_changeset(attrs)
    |> Repo.update()
  end

  ## 조회

  @spec list_reminders_for_invoice(binary()) :: [Reminder.t()]
  def list_reminders_for_invoice(invoice_id) do
    from(r in Reminder,
      where: r.invoice_id == ^invoice_id,
      order_by: [asc: r.step]
    )
    |> Repo.all()
  end

  @spec reminder_stats(binary()) :: map()
  def reminder_stats(user_id) do
    from(r in Reminder,
      join: i in assoc(r, :invoice),
      where: i.user_id == ^user_id,
      where: r.status == "sent",
      group_by: r.step,
      select: %{
        step: r.step,
        total_sent: count(r.id),
        total_opened: count(r.opened_at),
        total_clicked: count(r.clicked_at),
        open_rate: fragment("ROUND(COUNT(?) * 100.0 / NULLIF(COUNT(*), 0), 1)", r.opened_at),
        click_rate: fragment("ROUND(COUNT(?) * 100.0 / NULLIF(COUNT(*), 0), 1)", r.clicked_at)
      }
    )
    |> Repo.all()
  end

  ## Private

  defp calculate_send_time(due_date, offset_days, client_timezone) do
    target_date = Date.add(due_date, offset_days)
    target_date = skip_weekends(target_date)

    # 클라이언트 타임존 기준 오전 9~11시 랜덤
    hour = Enum.random(9..10)
    minute = Enum.random(0..59)

    {:ok, naive} = NaiveDateTime.new(target_date, Time.new!(hour, minute, 0))
    tz = client_timezone || "UTC"

    case DateTime.from_naive(naive, tz) do
      {:ok, dt} -> DateTime.shift_zone!(dt, "UTC")
      {:ambiguous, dt, _} -> DateTime.shift_zone!(dt, "UTC")
      {:gap, _, dt} -> DateTime.shift_zone!(dt, "UTC")
    end
  end

  defp skip_weekends(date) do
    case Date.day_of_week(date) do
      6 -> Date.add(date, 2)  # 토요일 → 월요일
      7 -> Date.add(date, 1)  # 일요일 → 월요일
      _ -> date
    end
  end

  defp get_template(step, user_id) do
    # 사용자 커스텀 템플릿 우선, 없으면 시스템 기본
    Repo.one(
      from(t in ReminderTemplate,
        where: t.step == ^step,
        where: t.user_id == ^user_id or (is_nil(t.user_id) and t.is_default == true),
        order_by: [desc: t.user_id],
        limit: 1
      )
    )
  end

  defp deliver_email(reminder, subject, body) do
    import Swoosh.Email

    tracking_pixel_url = InvoiceFlowWeb.Endpoint.url() <> "/track/open/#{reminder.id}"
    body_with_tracking = body <> ~s(<img src="#{tracking_pixel_url}" width="1" height="1" />)

    new()
    |> to({reminder.invoice.client.name, reminder.invoice.client.email})
    |> from({reminder.invoice.user.company_name || "InvoiceFlow", from_email()})
    |> subject(subject)
    |> html_body(body_with_tracking)
    |> InvoiceFlow.Mailer.deliver()
  end

  defp from_email, do: Application.fetch_env!(:invoice_flow, :from_email)
end
```

---

## 5. Oban Workers

### 5.1 ReminderWorker

```elixir
defmodule InvoiceFlow.Workers.ReminderWorker do
  use Oban.Worker,
    queue: :reminders,
    max_attempts: 5,
    priority: 2

  alias InvoiceFlow.Reminders

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"reminder_id" => reminder_id}}) do
    reminder = Reminders.get_reminder!(reminder_id)

    case reminder.status do
      status when status in ~w(cancelled) ->
        :ok  # 이미 취소됨, 무시

      "scheduled" ->
        case Reminders.send_reminder(reminder) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end

      _ ->
        :ok  # 이미 발송됨 or 다른 상태
    end
  end
end
```

### 5.2 DueDateCheckerWorker (Cron)

```elixir
defmodule InvoiceFlow.Workers.DueDateCheckerWorker do
  use Oban.Worker,
    queue: :default,
    max_attempts: 1

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Invoices.Invoice

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    today = Date.utc_today()

    # sent 상태이면서 마감일이 지난 송장 → overdue로 전환
    from(i in Invoice,
      where: i.status == "sent",
      where: i.due_date < ^today
    )
    |> Repo.all()
    |> Enum.each(fn invoice ->
      InvoiceFlow.Invoices.mark_as_overdue(invoice)
    end)

    :ok
  end
end
```

---

## 6. 이메일 추적 엔드포인트

```elixir
# 라우터에 추가
scope "/track", InvoiceFlowWeb do
  pipe_through :api

  get "/open/:reminder_id", TrackingController, :open
  get "/click/:reminder_id", TrackingController, :click
end
```

```elixir
defmodule InvoiceFlowWeb.TrackingController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Reminders

  # 1x1 투명 픽셀 (오픈 추적)
  @transparent_pixel Base.decode64!("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7")

  def open(conn, %{"reminder_id" => id}) do
    Reminders.record_open(id)

    conn
    |> put_resp_content_type("image/gif")
    |> send_resp(200, @transparent_pixel)
  end

  # 결제 링크 리디렉트 (클릭 추적)
  def click(conn, %{"reminder_id" => id}) do
    Reminders.record_click(id)
    reminder = Reminders.get_reminder!(id) |> Repo.preload(:invoice)

    redirect(conn, external: reminder.invoice.paddle_payment_link)
  end
end
```

---

## 7. 기본 이메일 템플릿 (시드 데이터)

### Step 1 (D+1) - Friendly

```
Subject: "<%= @invoice_number %> 결제 확인 부탁드립니다"

Body:
안녕하세요, <%= @client_name %>님.

<%= @company_name %>입니다.
송장 <%= @invoice_number %> (금액: <%= @currency %> <%= @amount %>)의
결제 마감일(<%= @due_date %>)이 지났습니다.

혹시 이미 처리하셨다면 무시해 주세요.
아직이시라면 아래 링크로 간편하게 결제하실 수 있습니다.

[결제하기](<%= @payment_link %>)

감사합니다.
```

### Step 2 (D+7) - Gentle

```
Subject: "알림: <%= @invoice_number %> 결제가 <%= @days_overdue %>일 지연되었습니다"

Body:
<%= @client_name %>님, 안녕하세요.

송장 <%= @invoice_number %>의 결제가 <%= @days_overdue %>일째 미처리 상태입니다.
결제에 어려움이 있으시면 편하게 말씀해 주세요.

금액: <%= @currency %> <%= @amount %>

[지금 결제하기](<%= @payment_link %>)

도움이 필요하시면 언제든 연락 주세요.
```

### Step 3 (D+14) - Firm

```
Subject: "최종 안내: <%= @invoice_number %> 결제 요청"

Body:
<%= @client_name %>님,

송장 <%= @invoice_number %> (금액: <%= @currency %> <%= @amount %>)의
결제가 <%= @days_overdue %>일 지연되고 있어 최종 안내드립니다.

7일 내 결제가 확인되지 않을 경우,
연체 수수료가 부과될 수 있습니다.

[즉시 결제하기](<%= @payment_link %>)

문의사항이 있으시면 회신해 주세요.
```

---

## 8. LiveView 플로우

### 8.1 송장 상세 - 리마인더 섹션

```
[송장 상세 페이지 - 리마인더 탭]
├─ 리마인더 타임라인
│   ├─ Step 1: [상태 뱃지] 예정 시각 / 발송 시각
│   │   ├─ 오픈 횟수, 클릭 횟수
│   │   └─ "미리보기" → 모달로 이메일 내용 표시
│   ├─ Step 2: ...
│   └─ Step 3: ...
├─ 액션
│   ├─ "리마인더 일시정지" → cancel_pending_reminders
│   └─ "지금 발송" → 즉시 send_reminder
└─ PubSub 구독
    └─ 이메일 오픈/클릭 시 실시간 업데이트
```

---

## 9. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| R-1 | 송장 발송 시 3개 리마인더 스케줄링 | Unit | step 1,2,3 생성, scheduled_at 계산 |
| R-2 | D+1 스케줄 시각 계산 | Unit | 마감일+1일, 클라이언트 TZ 오전 9~11시 |
| R-3 | 주말 건너뛰기 | Unit | 토요일 → 월요일 |
| R-4 | 결제 완료 시 리마인더 취소 | Unit | 모든 pending → cancelled, Oban 취소 |
| R-5 | 이메일 콘텐츠 생성 (Step 1) | Unit | 템플릿 변수 치환 확인 |
| R-6 | 이메일 콘텐츠 생성 (Step 3) | Unit | days_overdue 포함, firm 톤 |
| R-7 | 이메일 발송 성공 | Unit (Mock) | status: sent, sent_at 기록 |
| R-8 | 이메일 발송 실패 | Unit (Mock) | status: failed, Oban 재시도 |
| R-9 | 오픈 추적 (tracking pixel) | Unit | open_count 증가, opened_at 기록 |
| R-10 | 클릭 추적 (redirect) | Unit | click_count 증가, 결제 링크 리디렉트 |
| R-11 | DueDateChecker: 연체 전환 | Unit | sent + 마감 지남 → overdue |
| R-12 | 커스텀 템플릿 우선 적용 | Unit | user 템플릿 > 시스템 기본 |
| R-13 | 리마인더 통계 집계 | Unit | step별 발송/오픈/클릭 비율 |
| R-14 | 리마인더 타임라인 LiveView | Integration | 상태, 시간, 추적 데이터 표시 |
| R-15 | "지금 발송" 즉시 발송 | Integration | 버튼 클릭 → 즉시 이메일 발송 |
