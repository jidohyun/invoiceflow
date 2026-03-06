# 03 - Invoices Spec

> **구현 완료** | 2026-03-04 | 19 tests 통과 (64 tests 전체 기준)
> - Invoice 스키마 (번호 자동생성, 상태 전환 검증, 마감일 검증)
> - InvoiceItem 스키마 (수량*단가 자동 계산)
> - Invoices Context (CRUD, 상태 전환, 미수금 집계, PubSub 브로드캐스트)
> - can_create_invoice? Free 플랜 월 3건 제한

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | 송장 CRUD, 상태 관리, PDF 생성, LiveView Upload |
| **Context** | `InvoiceFlow.Invoices` |
| **의존성** | 01-accounts (User), 02-clients (Client) |
| **예상 기간** | Week 3~5 |

---

## 1. Ecto Schemas

### 1.1 Invoice

```elixir
defmodule InvoiceFlow.Invoices.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft sent overdue partially_paid paid cancelled)

  schema "invoices" do
    field :invoice_number, :string         # INV-YYYYMM-XXXX
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :due_date, :date
    field :status, :string, default: "draft"
    field :notes, :string

    # 파일
    field :pdf_url, :string
    field :original_file_url, :string      # 업로드된 원본 PDF/이미지

    # 결제
    field :paddle_payment_link, :string
    field :paid_at, :utc_datetime
    field :paid_amount, :decimal, default: Decimal.new(0)

    # 메타
    field :sent_at, :utc_datetime
    field :overdue_notified_at, :utc_datetime

    belongs_to :user, InvoiceFlow.Accounts.User
    belongs_to :client, InvoiceFlow.Clients.Client

    has_many :items, InvoiceFlow.Invoices.InvoiceItem, on_replace: :delete
    has_many :reminders, InvoiceFlow.Reminders.Reminder
    has_many :payments, InvoiceFlow.Payments.Payment

    timestamps(type: :utc_datetime)
  end

  @required_fields [:amount, :currency, :due_date, :client_id]
  @optional_fields [:notes, :status, :pdf_url, :original_file_url,
                     :paddle_payment_link, :paid_at, :paid_amount,
                     :sent_at, :overdue_notified_at]

  def create_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:currency, ~w(USD EUR KRW GBP JPY))
    |> validate_inclusion(:status, @statuses)
    |> validate_due_date_not_past()
    |> generate_invoice_number()
    |> cast_assoc(:items, with: &InvoiceFlow.Invoices.InvoiceItem.changeset/2)
    |> foreign_key_constraint(:client_id)
  end

  def update_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:currency, ~w(USD EUR KRW GBP JPY))
    |> validate_inclusion(:status, @statuses)
    |> validate_status_transition()
    |> cast_assoc(:items, with: &InvoiceFlow.Invoices.InvoiceItem.changeset/2)
  end

  def status_changeset(invoice, status) do
    invoice
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
    |> validate_status_transition()
  end

  def mark_paid_changeset(invoice, paid_at \\ DateTime.utc_now()) do
    invoice
    |> change(status: "paid", paid_at: paid_at, paid_amount: invoice.amount)
  end

  ## Private

  defp generate_invoice_number(changeset) do
    if get_field(changeset, :invoice_number) do
      changeset
    else
      now = Date.utc_today()
      prefix = "INV-#{Calendar.strftime(now, "%Y%m")}-"
      # 실제 구현 시 Repo에서 마지막 번호 조회
      put_change(changeset, :invoice_number, prefix <> random_suffix())
    end
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(2) |> Base.encode16() |> binary_part(0, 4)
  end

  defp validate_due_date_not_past(changeset) do
    due_date = get_change(changeset, :due_date)

    if due_date && Date.compare(due_date, Date.utc_today()) == :lt do
      add_error(changeset, :due_date, "마감일은 오늘 이후여야 합니다")
    else
      changeset
    end
  end

  @valid_transitions %{
    "draft" => ~w(sent cancelled),
    "sent" => ~w(overdue partially_paid paid cancelled),
    "overdue" => ~w(partially_paid paid cancelled),
    "partially_paid" => ~w(paid cancelled),
    "paid" => [],
    "cancelled" => ["draft"]
  }

  defp validate_status_transition(changeset) do
    old_status = changeset.data.status
    new_status = get_change(changeset, :status)

    cond do
      is_nil(new_status) -> changeset
      is_nil(old_status) -> changeset
      new_status in Map.get(@valid_transitions, old_status, []) -> changeset
      true -> add_error(changeset, :status, "#{old_status}에서 #{new_status}로 전환할 수 없습니다")
    end
  end
end
```

### 1.2 InvoiceItem

```elixir
defmodule InvoiceFlow.Invoices.InvoiceItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "invoice_items" do
    field :description, :string
    field :quantity, :decimal, default: Decimal.new(1)
    field :unit_price, :decimal
    field :total, :decimal
    field :position, :integer

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:description, :quantity, :unit_price, :position])
    |> validate_required([:description, :quantity, :unit_price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> calculate_total()
  end

  defp calculate_total(changeset) do
    quantity = get_field(changeset, :quantity) || Decimal.new(0)
    unit_price = get_field(changeset, :unit_price) || Decimal.new(0)
    put_change(changeset, :total, Decimal.mult(quantity, unit_price))
  end
end
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, references(:clients, type: :binary_id, on_delete: :restrict), null: false

      add :invoice_number, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string, default: "USD", null: false
      add :due_date, :date, null: false
      add :status, :string, default: "draft", null: false
      add :notes, :text

      add :pdf_url, :string
      add :original_file_url, :string

      add :paddle_payment_link, :string
      add :paid_at, :utc_datetime
      add :paid_amount, :decimal, precision: 12, scale: 2, default: 0

      add :sent_at, :utc_datetime
      add :overdue_notified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoices, [:invoice_number])
    create index(:invoices, [:user_id])
    create index(:invoices, [:client_id])
    create index(:invoices, [:status])
    create index(:invoices, [:due_date])
    create index(:invoices, [:user_id, :status])

    create table(:invoice_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :description, :string, null: false
      add :quantity, :decimal, precision: 10, scale: 2, default: 1
      add :unit_price, :decimal, precision: 12, scale: 2, null: false
      add :total, :decimal, precision: 12, scale: 2, null: false
      add :position, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:invoice_items, [:invoice_id])
  end
end
```

---

## 3. Context Functions

```elixir
defmodule InvoiceFlow.Invoices do
  @moduledoc "송장 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Invoices.{Invoice, InvoiceItem}
  alias InvoiceFlow.Accounts
  alias InvoiceFlow.PubSubTopics

  ## 조회

  @spec list_invoices(binary(), keyword()) :: [Invoice.t()]
  def list_invoices(user_id, opts \\ []) do
    status = Keyword.get(opts, :status)
    client_id = Keyword.get(opts, :client_id)
    sort_by = Keyword.get(opts, :sort_by, :due_date)
    sort_order = Keyword.get(opts, :sort_order, :desc)

    from(i in Invoice,
      where: i.user_id == ^user_id,
      preload: [:client, :items]
    )
    |> maybe_filter_status(status)
    |> maybe_filter_client(client_id)
    |> order_by([i], [{^sort_order, field(i, ^sort_by)}])
    |> Repo.all()
  end

  @spec get_invoice!(binary(), binary()) :: Invoice.t()
  def get_invoice!(user_id, id) do
    Invoice
    |> Repo.get_by!(id: id, user_id: user_id)
    |> Repo.preload([:client, :items, :reminders, :payments])
  end

  @spec get_invoice_by_number(String.t()) :: Invoice.t() | nil
  def get_invoice_by_number(invoice_number) do
    Invoice
    |> Repo.get_by(invoice_number: invoice_number)
    |> Repo.preload([:client, :items])
  end

  ## 생성

  @spec create_invoice(User.t(), map()) :: {:ok, Invoice.t()} | {:error, :plan_limit | Ecto.Changeset.t()}
  def create_invoice(user, attrs) do
    if Accounts.can_create_invoice?(user) do
      %Invoice{user_id: user.id}
      |> Invoice.create_changeset(attrs)
      |> Repo.insert()
      |> tap_ok(&broadcast_invoice_change/1)
    else
      {:error, :plan_limit}
    end
  end

  ## 수정

  @spec update_invoice(Invoice.t(), map()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def update_invoice(%Invoice{} = invoice, attrs) do
    invoice
    |> Invoice.update_changeset(attrs)
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  ## 상태 전환

  @spec mark_as_sent(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def mark_as_sent(%Invoice{} = invoice) do
    invoice
    |> Invoice.status_changeset("sent")
    |> Ecto.Changeset.put_change(:sent_at, DateTime.utc_now())
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
    |> tap_ok(&schedule_reminders/1)
  end

  @spec mark_as_paid(Invoice.t(), DateTime.t()) :: {:ok, Invoice.t()}
  def mark_as_paid(%Invoice{} = invoice, paid_at \\ DateTime.utc_now()) do
    invoice
    |> Invoice.mark_paid_changeset(paid_at)
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
    |> tap_ok(&cancel_pending_reminders/1)
    |> tap_ok(&update_client_stats/1)
  end

  @spec mark_as_overdue(Invoice.t()) :: {:ok, Invoice.t()}
  def mark_as_overdue(%Invoice{status: "sent"} = invoice) do
    invoice
    |> Invoice.status_changeset("overdue")
    |> Repo.update()
    |> tap_ok(&broadcast_invoice_change/1)
  end

  ## 삭제

  @spec delete_invoice(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def delete_invoice(%Invoice{status: "draft"} = invoice) do
    Repo.delete(invoice)
  end
  def delete_invoice(_invoice), do: {:error, :cannot_delete_non_draft}

  ## 집계

  @spec outstanding_summary(binary()) :: map()
  def outstanding_summary(user_id) do
    from(i in Invoice,
      where: i.user_id == ^user_id,
      where: i.status in ~w(sent overdue partially_paid),
      select: %{
        total: sum(i.amount - i.paid_amount),
        count: count(i.id),
        overdue_total: sum(fragment("CASE WHEN ? = 'overdue' THEN ? - ? ELSE 0 END",
          i.status, i.amount, i.paid_amount)),
        overdue_count: sum(fragment("CASE WHEN ? = 'overdue' THEN 1 ELSE 0 END", i.status))
      }
    )
    |> Repo.one()
  end

  ## PDF 생성

  @spec generate_pdf(Invoice.t()) :: {:ok, binary()} | {:error, term()}
  def generate_pdf(%Invoice{} = invoice) do
    invoice = Repo.preload(invoice, [:client, :items, :user])
    html = InvoiceFlowWeb.InvoicePdfView.render_to_string(invoice)

    case ChromicPDF.print_to_pdf({:html, html}) do
      {:ok, pdf_binary} -> {:ok, pdf_binary}
      error -> error
    end
  end

  @spec generate_and_upload_pdf(Invoice.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_and_upload_pdf(%Invoice{} = invoice) do
    with {:ok, pdf_binary} <- generate_pdf(invoice),
         {:ok, url} <- upload_to_s3(invoice, pdf_binary) do
      update_invoice(invoice, %{pdf_url: url})
      {:ok, url}
    end
  end

  ## Private

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: from(i in query, where: i.status == ^status)

  defp maybe_filter_client(query, nil), do: query
  defp maybe_filter_client(query, client_id), do: from(i in query, where: i.client_id == ^client_id)

  defp broadcast_invoice_change(%Invoice{} = invoice) do
    Phoenix.PubSub.broadcast(
      InvoiceFlow.PubSub,
      PubSubTopics.user_invoices(invoice.user_id),
      {:invoice_updated, invoice}
    )
  end

  defp schedule_reminders(%Invoice{} = invoice) do
    InvoiceFlow.Reminders.schedule_reminders(invoice)
  end

  defp cancel_pending_reminders(%Invoice{} = invoice) do
    InvoiceFlow.Reminders.cancel_pending_reminders(invoice.id)
  end

  defp update_client_stats(%Invoice{client_id: client_id}) do
    client = InvoiceFlow.Clients.get_client_by_id(client_id)
    InvoiceFlow.Clients.recalculate_stats(client)
  end

  defp upload_to_s3(%Invoice{invoice_number: number}, pdf_binary) do
    key = "invoices/#{number}.pdf"
    InvoiceFlow.Storage.upload(key, pdf_binary, content_type: "application/pdf")
  end

  defp tap_ok({:ok, result} = ok, func) do
    func.(result)
    ok
  end
  defp tap_ok(error, _func), do: error
end
```

---

## 4. LiveView 플로우

### 4.1 송장 목록 (InvoiceLive.Index)

```
[송장 목록]
├─ 상태 필터 탭 (전체 | 초안 | 발송됨 | 연체 | 결제완료)
│   └─ handle_event("filter_status") → list_invoices(status: status)
├─ PubSub 구독
│   └─ handle_info({:invoice_updated, invoice}) → 실시간 목록 갱신
├─ 송장 카드/행
│   ├─ invoice_number, 클라이언트명, 금액, 마감일
│   ├─ 상태 뱃지 (색상 코딩)
│   ├─ "보기" → navigate to /invoices/:id
│   └─ "삭제" (draft만) → 확인 모달
└─ "새 송장" 버튼
    └─ navigate to /invoices/new
```

### 4.2 송장 생성 (InvoiceLive.New)

```
[송장 생성 - 2탭 구조]
├─ 탭 1: 파일 업로드
│   ├─ LiveView Upload (드래그 앤 드롭)
│   │   ├─ accept: .pdf, .jpg, .png
│   │   ├─ max_file_size: 10MB
│   │   └─ progress 바 실시간 표시
│   └─ 업로드 완료 → Oban OcrExtractionWorker 시작
│       └─ PubSub 구독 → AI 추출 결과 실시간 반영
│
└─ 탭 2: 수동 입력
    ├─ 클라이언트 선택 (검색 가능 드롭다운)
    │   └─ 없으면 "새 클라이언트 추가" 인라인
    ├─ 마감일 (date picker)
    ├─ 통화 선택 (USD, EUR, KRW, ...)
    ├─ 항목 리스트 (동적 추가/삭제)
    │   ├─ description, quantity, unit_price
    │   ├─ 소계 자동 계산
    │   └─ "+ 항목 추가" 버튼
    ├─ 합계 표시
    ├─ 메모 (텍스트에어리어)
    └─ 액션 버튼
        ├─ "초안 저장" → create_invoice(status: "draft")
        └─ "저장 & 발송" → create_invoice → mark_as_sent → 이메일 발송
```

### 4.3 LiveView Upload 구현

```elixir
defmodule InvoiceFlowWeb.InvoiceLive.New do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.{Invoices, Clients}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "새 송장")
     |> assign(:clients, Clients.list_clients(socket.assigns.current_user.id))
     |> assign(:changeset, Invoices.change_invoice(%Invoices.Invoice{}))
     |> assign(:extraction_result, nil)
     |> allow_upload(:invoice_file,
       accept: ~w(.pdf .jpg .jpeg .png),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate", %{"invoice" => params}, socket) do
    changeset =
      %Invoices.Invoice{}
      |> Invoices.Invoice.create_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"invoice" => params}, socket) do
    user = socket.assigns.current_user

    case Invoices.create_invoice(user, params) do
      {:ok, invoice} ->
        {:noreply,
         socket
         |> put_flash(:info, "송장이 생성되었습니다.")
         |> push_navigate(to: ~p"/invoices/#{invoice}")}

      {:error, :plan_limit} ->
        {:noreply, put_flash(socket, :error, "Free 플랜의 월 3건 한도에 도달했습니다. 업그레이드해주세요.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def handle_event("send_invoice", %{"id" => id}, socket) do
    invoice = Invoices.get_invoice!(socket.assigns.current_user.id, id)

    case Invoices.mark_as_sent(invoice) do
      {:ok, _invoice} ->
        {:noreply, put_flash(socket, :info, "송장이 발송되었습니다.")}
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "발송에 실패했습니다.")}
    end
  end

  # 파일 업로드 완료 → OCR 작업 시작
  @impl true
  def handle_progress(:invoice_file, entry, socket) when entry.done? do
    uploaded_file =
      consume_uploaded_entry(socket, entry, fn %{path: path} ->
        dest = InvoiceFlow.Storage.upload_temp(path, entry.client_name)
        {:ok, dest}
      end)

    # Oban OCR 작업 시작
    %{file_url: uploaded_file, user_id: socket.assigns.current_user.id}
    |> InvoiceFlow.Workers.OcrExtractionWorker.new()
    |> Oban.insert()
    |> case do
      {:ok, job} ->
        # OCR 결과 PubSub 구독
        Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, PubSubTopics.extraction_completed(job.id))
        {:noreply, assign(socket, :extraction_job_id, job.id)}
    end
  end

  # OCR 결과 수신
  @impl true
  def handle_info({:extraction_completed, result}, socket) do
    changeset =
      %Invoices.Invoice{}
      |> Invoices.Invoice.create_changeset(result)

    {:noreply, assign(socket, changeset: changeset, extraction_result: result)}
  end
end
```

---

## 5. PDF 생성

### 5.1 PDF 템플릿 구조

```elixir
defmodule InvoiceFlowWeb.InvoicePdfView do
  @moduledoc "송장 PDF HTML 렌더링"

  def render_to_string(%Invoice{} = invoice) do
    # HEEx 템플릿으로 렌더링
    Phoenix.Template.render_to_string(
      InvoiceFlowWeb.InvoicePdfHTML,
      "invoice",
      %{invoice: invoice}
    )
  end
end
```

### 5.2 PDF 레이아웃 구성

```
┌─────────────────────────────────────┐
│  [로고/회사명]         INV-202603-A1B2 │
│  회사 주소                 발행일: ...  │
│                           마감일: ...  │
├─────────────────────────────────────┤
│  청구 대상:                            │
│  클라이언트명 / 회사 / 이메일          │
├─────────────────────────────────────┤
│  # │ 설명        │ 수량 │ 단가  │ 소계 │
│  1 │ 웹 디자인   │  1   │ $500  │ $500 │
│  2 │ 로고 디자인 │  1   │ $300  │ $300 │
├─────────────────────────────────────┤
│                         합계: $800    │
├─────────────────────────────────────┤
│  [Paddle 결제 버튼/링크]              │
│  메모: ...                            │
└─────────────────────────────────────┘
```

---

## 6. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| I-1 | 송장 생성 성공 | Unit | invoice_number 자동 생성, 상태 draft |
| I-2 | 금액 0 이하 거부 | Unit | validation error |
| I-3 | 과거 마감일 거부 | Unit | validation error |
| I-4 | 송장 항목 포함 생성 | Unit | items 연결, 소계 자동 계산 |
| I-5 | Free 플랜 4번째 송장 거부 | Unit | `{:error, :plan_limit}` 반환 |
| I-6 | draft → sent 상태 전환 | Unit | status 변경, sent_at 기록 |
| I-7 | sent → paid 상태 전환 | Unit | status, paid_at, paid_amount 갱신 |
| I-8 | paid → sent 전환 거부 | Unit | 유효하지 않은 상태 전환 에러 |
| I-9 | draft 송장만 삭제 가능 | Unit | sent 상태 삭제 시 에러 |
| I-10 | 미수금 집계 | Unit | total, overdue_total 계산 |
| I-11 | 상태 변경 시 PubSub 발행 | Unit | {:invoice_updated, invoice} 수신 |
| I-12 | PDF 생성 | Integration | ChromicPDF HTML → binary |
| I-13 | LiveView Upload 프로그레스 | Integration | 업로드 진행률 → 100% |
| I-14 | 송장 목록 상태 필터 | Integration | 탭 전환 시 필터 적용 |
| I-15 | 송장 폼 항목 동적 추가/삭제 | Integration | 항목 행 증감, 합계 재계산 |
| I-16 | 송장 실시간 업데이트 | Integration | PubSub → LiveView 자동 갱신 |
