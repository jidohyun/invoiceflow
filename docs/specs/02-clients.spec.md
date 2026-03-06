# 02 - Clients Spec

> **구현 완료** | 2026-03-04 | 11 tests 통과
> - Client 스키마 (연락처, 통계, user별 이메일 유니크 제약)
> - Clients Context (CRUD, 검색, 정렬)
> - 테스트: C-1 ~ C-9 시나리오 커버

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | 클라이언트(거래처) 정보 관리 |
| **Context** | `InvoiceFlow.Clients` |
| **의존성** | 01-accounts (User) |
| **예상 기간** | Week 2~3 |

---

## 1. Ecto Schemas

### 1.1 Client

```elixir
defmodule InvoiceFlow.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clients" do
    field :name, :string
    field :email, :string
    field :company, :string
    field :phone, :string
    field :address, :string
    field :timezone, :string, default: "UTC"
    field :notes, :string

    # 자동 계산 (결제 이력 기반)
    field :avg_payment_days, :integer
    field :total_invoiced, :decimal, default: Decimal.new(0)
    field :total_paid, :decimal, default: Decimal.new(0)

    belongs_to :user, InvoiceFlow.Accounts.User
    has_many :invoices, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  @required_fields [:name, :email]
  @optional_fields [:company, :phone, :address, :timezone, :notes]

  def changeset(client, attrs) do
    client
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/)
    |> validate_length(:name, min: 1, max: 200)
    |> validate_length(:company, max: 200)
    |> validate_length(:notes, max: 2000)
    |> unique_constraint([:user_id, :email], message: "이미 등록된 클라이언트 이메일입니다")
  end

  def stats_changeset(client, attrs) do
    client
    |> cast(attrs, [:avg_payment_days, :total_invoiced, :total_paid])
  end
end
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :string, null: false
      add :email, :string, null: false
      add :company, :string
      add :phone, :string
      add :address, :text
      add :timezone, :string, default: "UTC"
      add :notes, :text

      add :avg_payment_days, :integer
      add :total_invoiced, :decimal, precision: 12, scale: 2, default: 0
      add :total_paid, :decimal, precision: 12, scale: 2, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:clients, [:user_id])
    create unique_index(:clients, [:user_id, :email])
  end
end
```

---

## 3. Context Functions

```elixir
defmodule InvoiceFlow.Clients do
  @moduledoc "클라이언트 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Clients.Client

  ## 조회

  @spec list_clients(binary(), keyword()) :: [Client.t()]
  def list_clients(user_id, opts \\ []) do
    sort_by = Keyword.get(opts, :sort_by, :name)
    sort_order = Keyword.get(opts, :sort_order, :asc)
    search = Keyword.get(opts, :search)

    from(c in Client, where: c.user_id == ^user_id)
    |> maybe_search(search)
    |> order_by([c], [{^sort_order, field(c, ^sort_by)}])
    |> Repo.all()
  end

  @spec get_client!(binary(), binary()) :: Client.t()
  def get_client!(user_id, id) do
    Client
    |> Repo.get_by!(id: id, user_id: user_id)
  end

  @spec get_client_by_email(binary(), String.t()) :: Client.t() | nil
  def get_client_by_email(user_id, email) do
    Repo.get_by(Client, user_id: user_id, email: email)
  end

  ## 생성

  @spec create_client(binary(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def create_client(user_id, attrs) do
    %Client{user_id: user_id}
    |> Client.changeset(attrs)
    |> Repo.insert()
  end

  ## 수정

  @spec update_client(Client.t(), map()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def update_client(%Client{} = client, attrs) do
    client
    |> Client.changeset(attrs)
    |> Repo.update()
  end

  ## 삭제

  @spec delete_client(Client.t()) :: {:ok, Client.t()} | {:error, Ecto.Changeset.t()}
  def delete_client(%Client{} = client) do
    Repo.delete(client)
  end

  ## 통계 갱신

  @spec recalculate_stats(Client.t()) :: {:ok, Client.t()}
  def recalculate_stats(%Client{} = client) do
    stats =
      from(i in InvoiceFlow.Invoices.Invoice,
        where: i.client_id == ^client.id,
        select: %{
          total_invoiced: sum(i.amount),
          total_paid: sum(fragment("CASE WHEN ? = 'paid' THEN ? ELSE 0 END", i.status, i.amount)),
          avg_days: avg(fragment("CASE WHEN ? IS NOT NULL THEN EXTRACT(DAY FROM ? - ?) END",
            i.paid_at, i.paid_at, i.due_date))
        }
      )
      |> Repo.one()

    client
    |> Client.stats_changeset(%{
      total_invoiced: stats.total_invoiced || Decimal.new(0),
      total_paid: stats.total_paid || Decimal.new(0),
      avg_payment_days: stats.avg_days && trunc(stats.avg_days)
    })
    |> Repo.update()
  end

  ## 내부

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query
  defp maybe_search(query, search) do
    term = "%#{search}%"
    from(c in query, where: ilike(c.name, ^term) or ilike(c.email, ^term) or ilike(c.company, ^term))
  end
end
```

---

## 4. LiveView 플로우

### 4.1 클라이언트 목록 (ClientLive.Index)

```
[클라이언트 목록]
├─ 검색바
│   └─ handle_event("search") → phx-debounce 300ms → list_clients(search: term)
├─ 정렬 (이름, 회사, 총 송장액)
│   └─ handle_event("sort") → list_clients(sort_by: field)
├─ 클라이언트 카드/행
│   ├─ 이름, 이메일, 회사
│   ├─ 총 송장액 / 총 수금액
│   ├─ 평균 결제일수 뱃지 (초록/노랑/빨강)
│   ├─ "편집" → navigate to /clients/:id
│   └─ "삭제" → 확인 모달 → delete_client/1
└─ "새 클라이언트" 버튼
    └─ navigate to /clients/new
```

### 4.2 클라이언트 생성/편집 (ClientLive.New / Show)

```
[클라이언트 폼]
├─ name* (텍스트)
├─ email* (이메일)
├─ company (텍스트)
├─ phone (텍스트)
├─ address (텍스트에어리어)
├─ timezone (드롭다운)
├─ notes (텍스트에어리어)
└─ handle_event("validate") → 실시간 유효성 검사
    handle_event("save") → create_client/2 or update_client/2
```

### 4.3 LiveView 이벤트 핸들러

```elixir
defmodule InvoiceFlowWeb.ClientLive.Index do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.Clients

  @impl true
  def mount(_params, _session, socket) do
    clients = Clients.list_clients(socket.assigns.current_user.id)
    {:ok, assign(socket, clients: clients, search: "", sort_by: :name, sort_order: :asc)}
  end

  @impl true
  def handle_event("search", %{"search" => term}, socket) do
    clients = Clients.list_clients(
      socket.assigns.current_user.id,
      search: term,
      sort_by: socket.assigns.sort_by,
      sort_order: socket.assigns.sort_order
    )
    {:noreply, assign(socket, clients: clients, search: term)}
  end

  @impl true
  def handle_event("sort", %{"field" => field}, socket) do
    sort_by = String.to_existing_atom(field)
    sort_order = if socket.assigns.sort_by == sort_by, do: toggle_order(socket.assigns.sort_order), else: :asc

    clients = Clients.list_clients(
      socket.assigns.current_user.id,
      search: socket.assigns.search,
      sort_by: sort_by,
      sort_order: sort_order
    )
    {:noreply, assign(socket, clients: clients, sort_by: sort_by, sort_order: sort_order)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    client = Clients.get_client!(socket.assigns.current_user.id, id)
    {:ok, _} = Clients.delete_client(client)
    clients = Clients.list_clients(socket.assigns.current_user.id)
    {:noreply, assign(socket, clients: clients) |> put_flash(:info, "클라이언트가 삭제되었습니다.")}
  end

  defp toggle_order(:asc), do: :desc
  defp toggle_order(:desc), do: :asc
end
```

---

## 5. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| C-1 | 클라이언트 생성 성공 | Unit | name, email 저장, user_id 연결 |
| C-2 | 필수 필드 누락 시 실패 | Unit | name 또는 email 없으면 에러 |
| C-3 | 동일 user의 중복 이메일 거부 | Unit | unique constraint 에러 |
| C-4 | 다른 user는 같은 이메일 허용 | Unit | 생성 성공 |
| C-5 | 클라이언트 수정 | Unit | 필드 업데이트 확인 |
| C-6 | 클라이언트 삭제 | Unit | 삭제 후 조회 시 NotFound |
| C-7 | 목록 검색 (이름) | Unit | 검색어 포함 결과만 반환 |
| C-8 | 목록 검색 (이메일) | Unit | 이메일 부분 일치 |
| C-9 | 목록 정렬 (이름 ASC/DESC) | Unit | 정렬 순서 확인 |
| C-10 | 통계 재계산 | Unit | total_invoiced, avg_payment_days 갱신 |
| C-11 | 클라이언트 목록 LiveView | Integration | 검색, 정렬, 삭제 동작 |
| C-12 | 클라이언트 생성 LiveView | Integration | 폼 제출 → DB 저장 → 리다이렉트 |
