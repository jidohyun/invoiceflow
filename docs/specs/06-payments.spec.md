# 06 - Payments Spec

> **COMPLETED** — 2026-03-04
> Migration, Payment/PaddleWebhookEvent/Subscription schemas, Payments/Billing contexts implemented.
> 24 tests passing (116 total).

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | Paddle 결제 연동, Webhook 처리, 결제 상태 관리, 구독 빌링 |
| **Context** | `InvoiceFlow.Payments` + `InvoiceFlow.Billing` |
| **의존성** | 03-invoices (Invoice), 05-reminders (Reminder), 01-accounts (User) |
| **예상 기간** | Week 6~8 |

---

## 1. Ecto Schemas

### 1.1 Payment

```elixir
defmodule InvoiceFlow.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(completed refunded disputed)

  schema "payments" do
    field :paddle_transaction_id, :string
    field :amount, :decimal
    field :currency, :string
    field :status, :string, default: "completed"
    field :paid_at, :utc_datetime
    field :raw_webhook, :map             # Paddle 원본 페이로드

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:paddle_transaction_id, :amount, :currency, :status, :paid_at, :raw_webhook, :invoice_id])
    |> validate_required([:paddle_transaction_id, :amount, :status, :paid_at, :invoice_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:paddle_transaction_id)
  end
end
```

### 1.2 PaddleWebhookEvent

```elixir
defmodule InvoiceFlow.Payments.PaddleWebhookEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "paddle_webhook_events" do
    field :event_id, :string             # Paddle 이벤트 고유 ID
    field :event_type, :string           # transaction.completed 등
    field :payload, :map
    field :processed_at, :utc_datetime
    field :error_message, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_id, :event_type, :payload, :processed_at, :error_message])
    |> validate_required([:event_id, :event_type, :payload])
    |> unique_constraint(:event_id)
  end
end
```

### 1.3 Subscription (Billing)

```elixir
defmodule InvoiceFlow.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(active past_due cancelled paused)

  schema "subscriptions" do
    field :paddle_subscription_id, :string
    field :paddle_customer_id, :string
    field :plan, :string                 # starter | pro
    field :status, :string, default: "active"
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :user, InvoiceFlow.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:paddle_subscription_id, :paddle_customer_id, :plan,
                     :status, :current_period_start, :current_period_end, :cancelled_at])
    |> validate_required([:paddle_subscription_id, :plan, :status])
    |> validate_inclusion(:plan, ~w(starter pro))
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:paddle_subscription_id)
  end
end
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :restrict), null: false

      add :paddle_transaction_id, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string
      add :status, :string, default: "completed", null: false
      add :paid_at, :utc_datetime, null: false
      add :raw_webhook, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:paddle_transaction_id])
    create index(:payments, [:invoice_id])

    create table(:paddle_webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :processed_at, :utc_datetime
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:paddle_webhook_events, [:event_id])

    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :paddle_subscription_id, :string, null: false
      add :paddle_customer_id, :string
      add :plan, :string, null: false
      add :status, :string, default: "active", null: false
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:paddle_subscription_id])
    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:status])
  end
end
```

---

## 3. Paddle 결제 링크 생성

```elixir
defmodule InvoiceFlow.Payments.PaddleClient do
  @moduledoc "Paddle Billing API 클라이언트"

  @base_url "https://api.paddle.com"

  @spec create_payment_link(Invoice.t()) :: {:ok, String.t()} | {:error, term()}
  def create_payment_link(%{id: invoice_id, amount: amount, currency: currency} = invoice) do
    invoice = InvoiceFlow.Repo.preload(invoice, [:client, :user])

    body = %{
      items: [
        %{
          price: %{
            description: "Invoice #{invoice.invoice_number}",
            unit_price: %{
              amount: Decimal.to_string(Decimal.mult(amount, 100)) |> String.split(".") |> hd(),
              currency_code: String.upcase(currency)
            },
            product: %{
              name: "Invoice Payment - #{invoice.invoice_number}",
              description: "Payment for invoice #{invoice.invoice_number}"
            }
          },
          quantity: 1
        }
      ],
      customer: %{
        email: invoice.client.email
      },
      custom_data: %{
        invoice_id: invoice_id,
        user_id: invoice.user_id
      },
      checkout: %{
        url: InvoiceFlowWeb.Endpoint.url() <> "/payments/success"
      }
    }

    case Req.post(
      "#{@base_url}/transactions",
      json: body,
      headers: [{"Authorization", "Bearer #{api_key()}"}]
    ) do
      {:ok, %{status: 200, body: %{"data" => %{"checkout" => %{"url" => url}}}}} ->
        {:ok, url}

      {:ok, %{status: status, body: body}} ->
        {:error, "Paddle API error: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec create_subscription_checkout(User.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_subscription_checkout(user, plan) do
    price_id = price_id_for(plan)

    body = %{
      items: [%{price_id: price_id, quantity: 1}],
      customer: %{email: user.email},
      custom_data: %{user_id: user.id, plan: plan}
    }

    case Req.post(
      "#{@base_url}/transactions",
      json: body,
      headers: [{"Authorization", "Bearer #{api_key()}"}]
    ) do
      {:ok, %{status: 200, body: %{"data" => %{"checkout" => %{"url" => url}}}}} ->
        {:ok, url}

      {:ok, %{status: status, body: body}} ->
        {:error, "Paddle API error: #{status}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp price_id_for("starter"), do: Application.fetch_env!(:invoice_flow, :paddle_starter_price_id)
  defp price_id_for("pro"), do: Application.fetch_env!(:invoice_flow, :paddle_pro_price_id)

  defp api_key, do: Application.fetch_env!(:invoice_flow, :paddle_api_key)
end
```

---

## 4. Webhook Controller

```elixir
defmodule InvoiceFlowWeb.WebhookController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Payments
  alias InvoiceFlow.Payments.PaddleWebhookEvent

  plug :verify_paddle_signature

  def paddle(conn, params) do
    event_id = params["event_id"]
    event_type = params["event_type"]

    # 멱등성: 중복 이벤트 무시
    case Payments.get_webhook_event(event_id) do
      nil ->
        {:ok, event} = Payments.log_webhook_event(%{
          event_id: event_id,
          event_type: event_type,
          payload: params
        })

        case process_event(event_type, params) do
          :ok ->
            Payments.mark_event_processed(event)
            send_resp(conn, 200, "OK")

          {:error, reason} ->
            Payments.mark_event_failed(event, inspect(reason))
            send_resp(conn, 200, "OK")  # Paddle에는 200 반환 (재시도 방지)
        end

      _existing ->
        send_resp(conn, 200, "OK")  # 이미 처리됨
    end
  end

  ## 이벤트 처리

  defp process_event("transaction.completed", %{"data" => data}) do
    Payments.process_transaction_completed(data)
  end

  defp process_event("transaction.payment_failed", %{"data" => data}) do
    Payments.process_payment_failed(data)
  end

  defp process_event("subscription.activated", %{"data" => data}) do
    InvoiceFlow.Billing.activate_subscription(data)
  end

  defp process_event("subscription.canceled", %{"data" => data}) do
    InvoiceFlow.Billing.cancel_subscription(data)
  end

  defp process_event("subscription.updated", %{"data" => data}) do
    InvoiceFlow.Billing.update_subscription(data)
  end

  defp process_event(_event_type, _data), do: :ok  # 미지원 이벤트 무시

  ## 서명 검증

  defp verify_paddle_signature(conn, _opts) do
    webhook_secret = Application.fetch_env!(:invoice_flow, :paddle_webhook_secret)

    with [signature] <- get_req_header(conn, "paddle-signature"),
         {:ok, body, conn} <- read_body(conn),
         true <- valid_signature?(body, signature, webhook_secret) do
      conn
      |> assign(:raw_body, body)
    else
      _ ->
        conn
        |> send_resp(401, "Invalid signature")
        |> halt()
    end
  end

  defp valid_signature?(body, signature, secret) do
    # Paddle V2 서명 검증
    parts = String.split(signature, ";")
    ts = Enum.find_value(parts, fn p -> String.starts_with?(p, "ts=") && String.replace_prefix(p, "ts=", "") end)
    h1 = Enum.find_value(parts, fn p -> String.starts_with?(p, "h1=") && String.replace_prefix(p, "h1=", "") end)

    if ts && h1 do
      signed_payload = "#{ts}:#{body}"
      expected = :crypto.mac(:hmac, :sha256, secret, signed_payload) |> Base.encode16(case: :lower)
      Plug.Crypto.secure_compare(expected, h1)
    else
      false
    end
  end
end
```

---

## 5. Context Functions

### 5.1 Payments Context

```elixir
defmodule InvoiceFlow.Payments do
  @moduledoc "결제 처리 및 Webhook 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Payments.{Payment, PaddleWebhookEvent, PaddleClient}
  alias InvoiceFlow.{Invoices, Reminders}
  alias InvoiceFlow.PubSubTopics

  ## 결제 링크

  @spec generate_payment_link(Invoice.t()) :: {:ok, Invoice.t()} | {:error, term()}
  def generate_payment_link(invoice) do
    case PaddleClient.create_payment_link(invoice) do
      {:ok, url} ->
        Invoices.update_invoice(invoice, %{paddle_payment_link: url})

      error ->
        error
    end
  end

  ## 결제 완료 처리 (Webhook)

  @spec process_transaction_completed(map()) :: :ok | {:error, term()}
  def process_transaction_completed(data) do
    invoice_id = get_in(data, ["custom_data", "invoice_id"])
    transaction_id = data["id"]

    with invoice when not is_nil(invoice) <- Repo.get(Invoices.Invoice, invoice_id),
         {:ok, _payment} <- create_payment(invoice, data),
         {:ok, invoice} <- Invoices.mark_as_paid(invoice) do
      # 실시간 알림
      Phoenix.PubSub.broadcast(
        InvoiceFlow.PubSub,
        PubSubTopics.payment_received(invoice.id),
        {:payment_received, invoice}
      )

      :ok
    else
      nil -> {:error, :invoice_not_found}
      error -> error
    end
  end

  @spec process_payment_failed(map()) :: :ok
  def process_payment_failed(_data) do
    # 결제 실패 로깅 (현재 MVP에서는 별도 처리 없음)
    :ok
  end

  ## Payment CRUD

  @spec create_payment(Invoice.t(), map()) :: {:ok, Payment.t()} | {:error, Ecto.Changeset.t()}
  def create_payment(invoice, webhook_data) do
    amount = get_in(webhook_data, ["details", "totals", "total"])
    currency = get_in(webhook_data, ["currency_code"])

    %Payment{invoice_id: invoice.id}
    |> Payment.changeset(%{
      paddle_transaction_id: webhook_data["id"],
      amount: parse_paddle_amount(amount),
      currency: currency,
      status: "completed",
      paid_at: DateTime.utc_now(),
      raw_webhook: webhook_data
    })
    |> Repo.insert()
  end

  @spec list_payments_for_invoice(binary()) :: [Payment.t()]
  def list_payments_for_invoice(invoice_id) do
    from(p in Payment,
      where: p.invoice_id == ^invoice_id,
      order_by: [desc: p.paid_at]
    )
    |> Repo.all()
  end

  ## Webhook 이벤트 로그

  @spec get_webhook_event(String.t()) :: PaddleWebhookEvent.t() | nil
  def get_webhook_event(event_id) do
    Repo.get_by(PaddleWebhookEvent, event_id: event_id)
  end

  @spec log_webhook_event(map()) :: {:ok, PaddleWebhookEvent.t()}
  def log_webhook_event(attrs) do
    %PaddleWebhookEvent{}
    |> PaddleWebhookEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec mark_event_processed(PaddleWebhookEvent.t()) :: {:ok, PaddleWebhookEvent.t()}
  def mark_event_processed(event) do
    event
    |> PaddleWebhookEvent.changeset(%{processed_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @spec mark_event_failed(PaddleWebhookEvent.t(), String.t()) :: {:ok, PaddleWebhookEvent.t()}
  def mark_event_failed(event, error_message) do
    event
    |> PaddleWebhookEvent.changeset(%{error_message: error_message})
    |> Repo.update()
  end

  ## Private

  defp parse_paddle_amount(nil), do: Decimal.new(0)
  defp parse_paddle_amount(amount) when is_binary(amount) do
    # Paddle은 cent 단위 → dollar 변환
    {cents, _} = Integer.parse(amount)
    Decimal.div(Decimal.new(cents), Decimal.new(100))
  end
  defp parse_paddle_amount(amount) when is_integer(amount) do
    Decimal.div(Decimal.new(amount), Decimal.new(100))
  end
end
```

### 5.2 Billing Context

```elixir
defmodule InvoiceFlow.Billing do
  @moduledoc "구독 플랜 및 빌링 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Billing.Subscription
  alias InvoiceFlow.Accounts

  ## 구독 활성화 (Webhook)

  @spec activate_subscription(map()) :: :ok | {:error, term()}
  def activate_subscription(data) do
    user_id = get_in(data, ["custom_data", "user_id"])
    plan = get_in(data, ["custom_data", "plan"])

    with {:ok, _sub} <- create_or_update_subscription(user_id, data, plan),
         user <- Accounts.get_user!(user_id),
         {:ok, _user} <- Accounts.update_profile(user, %{
           plan: plan,
           paddle_customer_id: data["customer_id"]
         }) do
      :ok
    end
  end

  ## 구독 취소 (Webhook)

  @spec cancel_subscription(map()) :: :ok
  def cancel_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: "cancelled",
          cancelled_at: DateTime.utc_now()
        })
        |> Repo.update()

        # 사용자 플랜 다운그레이드 (현재 기간 종료 시)
        :ok

      nil ->
        :ok
    end
  end

  ## 구독 업데이트 (Webhook)

  @spec update_subscription(map()) :: :ok
  def update_subscription(data) do
    sub_id = data["id"]

    case get_subscription_by_paddle_id(sub_id) do
      %Subscription{} = sub ->
        sub
        |> Subscription.changeset(%{
          status: data["status"],
          current_period_start: parse_datetime(data["current_billing_period"]["starts_at"]),
          current_period_end: parse_datetime(data["current_billing_period"]["ends_at"])
        })
        |> Repo.update()

        :ok

      nil ->
        :ok
    end
  end

  ## 조회

  @spec get_active_subscription(binary()) :: Subscription.t() | nil
  def get_active_subscription(user_id) do
    from(s in Subscription,
      where: s.user_id == ^user_id,
      where: s.status == "active",
      order_by: [desc: s.inserted_at],
      limit: 1
    )
    |> Repo.one()
  end

  ## Private

  defp create_or_update_subscription(user_id, data, plan) do
    attrs = %{
      paddle_subscription_id: data["id"],
      paddle_customer_id: data["customer_id"],
      plan: plan,
      status: "active",
      current_period_start: parse_datetime(get_in(data, ["current_billing_period", "starts_at"])),
      current_period_end: parse_datetime(get_in(data, ["current_billing_period", "ends_at"]))
    }

    case get_subscription_by_paddle_id(data["id"]) do
      nil ->
        %Subscription{user_id: user_id}
        |> Subscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> Subscription.changeset(attrs)
        |> Repo.update()
    end
  end

  defp get_subscription_by_paddle_id(paddle_id) do
    Repo.get_by(Subscription, paddle_subscription_id: paddle_id)
  end

  defp parse_datetime(nil), do: nil
  defp parse_datetime(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> dt
      _ -> nil
    end
  end
end
```

---

## 6. 결제 플로우 다이어그램

```
[클라이언트: 이메일 내 "결제하기" 클릭]
│
├─ Paddle Checkout 페이지 (Paddle 호스팅)
│   └─ 카드/PayPal/Apple Pay 결제
│
├─ 결제 완료
│   └─ Paddle → POST /webhooks/paddle
│       ├─ 서명 검증 (HMAC SHA-256)
│       ├─ 멱등성 체크 (event_id 중복 확인)
│       ├─ Webhook 이벤트 로깅
│       └─ process_transaction_completed()
│           ├─ Payment 레코드 생성
│           ├─ Invoice.status → "paid"
│           ├─ Invoice.paid_at 기록
│           ├─ 리마인더 취소 (cancel_pending_reminders)
│           ├─ 클라이언트 통계 갱신 (recalculate_stats)
│           └─ PubSub broadcast
│               ├─ LiveView 대시보드 즉시 업데이트
│               └─ (향후) Phoenix Channel → 모바일 푸시
│
└─ 결제 실패
    └─ Paddle → POST /webhooks/paddle (payment_failed)
        └─ 로깅만 (리마인더 계속 진행)
```

---

## 7. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| P-1 | 결제 링크 생성 | Unit (Mock) | Paddle API 호출, URL 반환 |
| P-2 | 결제 링크를 송장에 저장 | Unit | invoice.paddle_payment_link 업데이트 |
| P-3 | Webhook 서명 검증 성공 | Unit | 유효 서명 → 처리 진행 |
| P-4 | Webhook 서명 검증 실패 | Unit | 401 응답 |
| P-5 | 중복 Webhook 멱등성 | Unit | 같은 event_id → 무시, 200 반환 |
| P-6 | transaction.completed 처리 | Unit | Payment 생성, Invoice paid 전환 |
| P-7 | 결제 완료 시 리마인더 취소 | Unit | pending 리마인더 → cancelled |
| P-8 | 결제 완료 시 PubSub 발행 | Unit | {:payment_received, invoice} 브로드캐스트 |
| P-9 | 결제 완료 시 클라이언트 통계 갱신 | Unit | avg_payment_days 재계산 |
| P-10 | subscription.activated 처리 | Unit | Subscription 생성, User plan 업데이트 |
| P-11 | subscription.canceled 처리 | Unit | Subscription cancelled, plan 다운그레이드 |
| P-12 | Paddle 금액 파싱 (cent→dollar) | Unit | 150000 → $1500.00 |
| P-13 | 존재하지 않는 invoice_id | Unit | {:error, :invoice_not_found} |
| P-14 | 결제 완료 LiveView 실시간 반영 | Integration | 대시보드 상태 즉시 업데이트 |
| P-15 | 구독 체크아웃 플로우 | Integration | 업그레이드 버튼 → Paddle URL 리디렉트 |
