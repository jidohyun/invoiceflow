# 00 - Foundation Spec

> **구현 완료** | 2026-03-04 | 45 tests 통과 (전체 기준)
> - Phoenix 1.8.3 프로젝트 초기화, Oban/Cachex/Swoosh/Sentry 설정
> - PubSubTopics, Errors, Mailer 공통 모듈 구현
> - Supervision Tree 구성 완료

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | Phoenix 프로젝트 초기 설정 및 공통 인프라 구성 |
| **범위** | 프로젝트 생성, 의존성, Supervision Tree, 배포, CI/CD |
| **의존성** | 없음 (모든 Spec의 기반) |
| **예상 기간** | Week 1 |

---

## 1. 프로젝트 초기화

### 1.1 Phoenix 프로젝트 생성

```bash
mix phx.new invoice_flow --database postgres --live
cd invoice_flow
```

### 1.2 핵심 의존성 (mix.exs)

```elixir
defp deps do
  [
    # Phoenix 코어
    {:phoenix, "~> 1.7"},
    {:phoenix_ecto, "~> 4.5"},
    {:ecto_sql, "~> 3.11"},
    {:postgrex, ">= 0.0.0"},
    {:phoenix_html, "~> 4.1"},
    {:phoenix_live_reload, "~> 1.5", only: :dev},
    {:phoenix_live_view, "~> 1.0"},
    {:phoenix_live_dashboard, "~> 0.8"},

    # 백그라운드 잡
    {:oban, "~> 2.17"},

    # 이메일
    {:swoosh, "~> 1.16"},
    {:req, "~> 0.5"},          # HTTP 클라이언트 (Resend, OpenAI, Paddle)

    # 인증
    {:ueberauth, "~> 0.10"},
    {:ueberauth_google, "~> 0.12"},

    # 캐싱
    {:cachex, "~> 3.6"},

    # 파일 저장소
    {:ex_aws, "~> 2.5"},
    {:ex_aws_s3, "~> 2.5"},

    # PDF 생성
    {:chromic_pdf, "~> 1.15"},

    # 모니터링
    {:sentry, "~> 10.0"},
    {:telemetry_metrics, "~> 1.0"},
    {:telemetry_poller, "~> 1.0"},

    # 코드 품질
    {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
    {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
    {:ex_machina, "~> 2.7", only: :test},
    {:mox, "~> 1.1", only: :test},

    # Tailwind
    {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
    {:heroicons, "~> 0.5"},
  ]
end
```

### 1.3 Oban 설정 (config/config.exs)

```elixir
config :invoice_flow, Oban,
  repo: InvoiceFlow.Repo,
  queues: [
    default: 10,
    reminders: 5,
    extraction: 3,
    pdf: 3,
    email_tracking: 5
  ],
  plugins: [
    Oban.Plugins.Pruner,
    {Oban.Plugins.Cron,
     crontab: [
       # 매일 오전 8시(UTC) 마감일 체크 → 리마인더 스케줄링
       {"0 8 * * *", InvoiceFlow.Workers.DueDateCheckerWorker}
     ]}
  ]
```

### 1.4 Swoosh 설정

```elixir
# config/config.exs
config :invoice_flow, InvoiceFlow.Mailer,
  adapter: Swoosh.Adapters.Req,
  api_key: {:system, "RESEND_API_KEY"},
  base_url: "https://api.resend.com"

# config/dev.exs
config :invoice_flow, InvoiceFlow.Mailer,
  adapter: Swoosh.Adapters.Local
```

---

## 2. Supervision Tree

```elixir
# lib/invoice_flow/application.ex
defmodule InvoiceFlow.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      InvoiceFlowWeb.Telemetry,
      InvoiceFlow.Repo,
      {DNSCluster, query: Application.get_env(:invoice_flow, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: InvoiceFlow.PubSub},
      {Cachex, name: :invoice_flow_cache},
      {Oban, Application.fetch_env!(:invoice_flow, Oban)},
      InvoiceFlowWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: InvoiceFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    InvoiceFlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
```

---

## 3. 공통 모듈

### 3.1 Mailer

```elixir
# lib/invoice_flow/mailer.ex
defmodule InvoiceFlow.Mailer do
  use Swoosh.Mailer, otp_app: :invoice_flow
end
```

### 3.2 PubSub 토픽 규약

```elixir
# lib/invoice_flow/pub_sub_topics.ex
defmodule InvoiceFlow.PubSubTopics do
  @moduledoc "PubSub 토픽 이름 중앙 관리"

  def invoice_updated(invoice_id), do: "invoice:#{invoice_id}"
  def user_invoices(user_id), do: "user:#{user_id}:invoices"
  def extraction_completed(job_id), do: "extraction:#{job_id}"
  def payment_received(invoice_id), do: "payment:#{invoice_id}"
end
```

### 3.3 에러 타입

```elixir
# lib/invoice_flow/errors.ex
defmodule InvoiceFlow.Errors do
  defmodule NotFound do
    defexception [:message, :resource, :id]

    @impl true
    def message(%{resource: resource, id: id}) do
      "#{resource} not found: #{id}"
    end
  end

  defmodule Unauthorized do
    defexception [:message]
  end

  defmodule ValidationError do
    defexception [:message, :changeset]
  end
end
```

---

## 4. 라우터 골격

```elixir
# lib/invoice_flow_web/router.ex
defmodule InvoiceFlowWeb.Router do
  use InvoiceFlowWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {InvoiceFlowWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # 인증 불필요
  scope "/", InvoiceFlowWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # 인증 필요 (LiveView)
  live_session :authenticated,
    on_mount: [{InvoiceFlowWeb.UserAuth, :ensure_authenticated}] do
    scope "/", InvoiceFlowWeb do
      pipe_through [:browser, :require_authenticated_user]

      live "/dashboard", DashboardLive.Index, :index
      live "/invoices", InvoiceLive.Index, :index
      live "/invoices/new", InvoiceLive.New, :new
      live "/invoices/:id", InvoiceLive.Show, :show
      live "/invoices/:id/edit", InvoiceLive.Edit, :edit
      live "/clients", ClientLive.Index, :index
      live "/clients/new", ClientLive.New, :new
      live "/clients/:id", ClientLive.Show, :show
      live "/settings", SettingsLive.Index, :index
    end
  end

  # Paddle Webhook (인증 불필요, 서명 검증)
  scope "/webhooks", InvoiceFlowWeb do
    pipe_through :api

    post "/paddle", WebhookController, :paddle
  end

  # LiveDashboard (dev/admin)
  if Application.compile_env(:invoice_flow, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: InvoiceFlowWeb.Telemetry
    end
  end
end
```

---

## 5. 환경 변수

```bash
# .env.example
DATABASE_URL=postgres://localhost/invoice_flow_dev
SECRET_KEY_BASE=

# 인증
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# 이메일
RESEND_API_KEY=
FROM_EMAIL=noreply@invoiceflow.io

# AI
OPENAI_API_KEY=

# 결제
PADDLE_API_KEY=
PADDLE_WEBHOOK_SECRET=

# 파일 저장소
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=
S3_BUCKET=invoiceflow-uploads
S3_REGION=us-east-1

# 모니터링
SENTRY_DSN=

# Fly.io
FLY_APP_NAME=invoice-flow
```

---

## 6. CI/CD (GitHub Actions)

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

env:
  MIX_ENV: test
  ELIXIR_VERSION: "1.16"
  OTP_VERSION: "26"

jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        ports: ["5432:5432"]
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4
      - uses: erlef/setup-beam@v1
        with:
          elixir-version: ${{ env.ELIXIR_VERSION }}
          otp-version: ${{ env.OTP_VERSION }}

      - name: Cache deps
        uses: actions/cache@v4
        with:
          path: deps
          key: deps-${{ runner.os }}-${{ hashFiles('mix.lock') }}

      - name: Cache build
        uses: actions/cache@v4
        with:
          path: _build
          key: build-${{ runner.os }}-${{ env.MIX_ENV }}-${{ hashFiles('mix.lock') }}

      - run: mix deps.get
      - run: mix compile --warnings-as-errors
      - run: mix format --check-formatted
      - run: mix credo --strict
      - run: mix dialyzer
      - run: mix test
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost/invoice_flow_test
```

---

## 7. Fly.io 배포

```toml
# fly.toml
app = "invoice-flow"
primary_region = "nrt"  # Tokyo (한국 근접)

[build]
  [build.args]
    ELIXIR_VERSION = "1.16"
    OTP_VERSION = "26"

[env]
  PHX_HOST = "invoiceflow.io"
  PORT = "8080"
  POOL_SIZE = "10"

[http_service]
  internal_port = 8080
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 800
```

---

## 8. 테스트 시나리오

| # | 시나리오 | 검증 항목 |
|---|----------|-----------|
| F-1 | `mix phx.server` 정상 기동 | HTTP 200 응답 |
| F-2 | Oban 큐 초기화 | `Oban.config()` 큐 확인 |
| F-3 | PubSub 메시지 발행/구독 | 토픽 브로드캐스트 수신 |
| F-4 | Cachex 캐시 읽기/쓰기 | get/put 동작 |
| F-5 | Swoosh 로컬 이메일 발송 | dev mailbox 확인 |
| F-6 | LiveDashboard 접근 | `/dev/dashboard` HTTP 200 |
| F-7 | 데이터베이스 마이그레이션 | `mix ecto.migrate` 성공 |
| F-8 | CI 파이프라인 통과 | format, credo, dialyzer, test |
