# 04 - Extraction Spec

> **구현 완료** | 2026-03-04 | 15 tests 통과 (79 tests 전체 기준)
> - ExtractionJob 스키마 (파일 유형 검증, 신뢰도 범위 검증)
> - Extraction Context (상태 전환, 결과 저장, PubSub 브로드캐스트)
> - 데이터 변환 (금액 파싱 $,쉼표 처리, 날짜 변환, 항목 변환)
> - 클라이언트 매칭 (이메일 기반 기존 클라이언트 조회 또는 제안)

## Domain Overview

| 항목 | 내용 |
|------|------|
| **목적** | AI OCR로 송장 파일에서 금액, 마감일, 클라이언트 정보 자동 추출 |
| **Context** | `InvoiceFlow.Extraction` |
| **의존성** | 03-invoices (Invoice), 02-clients (Client) |
| **예상 기간** | Week 4~5 (Invoices와 병렬 가능) |

---

## 1. Ecto Schemas

### 1.1 ExtractionJob

```elixir
defmodule InvoiceFlow.Extraction.ExtractionJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending processing completed failed)

  schema "extraction_jobs" do
    field :file_url, :string
    field :file_type, :string           # pdf | jpg | png
    field :status, :string, default: "pending"
    field :error_message, :string

    # AI 추출 결과 (JSON)
    field :raw_response, :map
    field :extracted_data, :map         # 정제된 구조화 데이터
    field :confidence_score, :float     # 0.0 ~ 1.0

    # 처리 메타
    field :processing_started_at, :utc_datetime
    field :processing_completed_at, :utc_datetime
    field :oban_job_id, :integer

    belongs_to :user, InvoiceFlow.Accounts.User
    belongs_to :invoice, InvoiceFlow.Invoices.Invoice  # 결과 적용된 송장 (nullable)

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [:file_url, :file_type, :status, :error_message,
                     :raw_response, :extracted_data, :confidence_score,
                     :processing_started_at, :processing_completed_at,
                     :oban_job_id, :invoice_id])
    |> validate_required([:file_url, :file_type])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:file_type, ~w(pdf jpg jpeg png))
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end
```

### 1.2 추출 결과 구조 (extracted_data 스키마)

```elixir
# extracted_data 맵의 기대 구조:
%{
  "client_name" => "Acme Corp",
  "client_email" => "billing@acme.com",
  "client_company" => "Acme Corporation",
  "amount" => "1500.00",
  "currency" => "USD",
  "due_date" => "2026-04-15",
  "invoice_number" => "INV-2026-001",
  "items" => [
    %{
      "description" => "Web Design Services",
      "quantity" => "1",
      "unit_price" => "1000.00"
    },
    %{
      "description" => "Logo Design",
      "quantity" => "1",
      "unit_price" => "500.00"
    }
  ],
  "notes" => "Net 30 payment terms"
}
```

---

## 2. 마이그레이션

```elixir
defmodule InvoiceFlow.Repo.Migrations.CreateExtractionJobs do
  use Ecto.Migration

  def change do
    create table(:extraction_jobs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :nilify_all)

      add :file_url, :string, null: false
      add :file_type, :string, null: false
      add :status, :string, default: "pending", null: false
      add :error_message, :text

      add :raw_response, :map
      add :extracted_data, :map
      add :confidence_score, :float

      add :processing_started_at, :utc_datetime
      add :processing_completed_at, :utc_datetime
      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:extraction_jobs, [:user_id])
    create index(:extraction_jobs, [:status])
  end
end
```

---

## 3. Context Functions

```elixir
defmodule InvoiceFlow.Extraction do
  @moduledoc "AI OCR 송장 데이터 추출 Context"

  alias InvoiceFlow.Repo
  alias InvoiceFlow.Extraction.ExtractionJob
  alias InvoiceFlow.Workers.OcrExtractionWorker
  alias InvoiceFlow.PubSubTopics

  ## 작업 생성 & 시작

  @spec start_extraction(binary(), String.t(), String.t()) :: {:ok, ExtractionJob.t()}
  def start_extraction(user_id, file_url, file_type) do
    {:ok, job} =
      %ExtractionJob{user_id: user_id}
      |> ExtractionJob.changeset(%{file_url: file_url, file_type: file_type})
      |> Repo.insert()

    {:ok, oban_job} =
      %{extraction_job_id: job.id}
      |> OcrExtractionWorker.new(queue: :extraction)
      |> Oban.insert()

    job
    |> ExtractionJob.changeset(%{oban_job_id: oban_job.id})
    |> Repo.update()
  end

  ## 상태 조회

  @spec get_job!(binary()) :: ExtractionJob.t()
  def get_job!(id), do: Repo.get!(ExtractionJob, id)

  @spec get_job_by_oban_id(integer()) :: ExtractionJob.t() | nil
  def get_job_by_oban_id(oban_job_id) do
    Repo.get_by(ExtractionJob, oban_job_id: oban_job_id)
  end

  ## 결과 저장

  @spec mark_processing(ExtractionJob.t()) :: {:ok, ExtractionJob.t()}
  def mark_processing(%ExtractionJob{} = job) do
    job
    |> ExtractionJob.changeset(%{
      status: "processing",
      processing_started_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @spec save_result(ExtractionJob.t(), map(), map(), float()) :: {:ok, ExtractionJob.t()}
  def save_result(%ExtractionJob{} = job, raw_response, extracted_data, confidence) do
    {:ok, updated_job} =
      job
      |> ExtractionJob.changeset(%{
        status: "completed",
        raw_response: raw_response,
        extracted_data: extracted_data,
        confidence_score: confidence,
        processing_completed_at: DateTime.utc_now()
      })
      |> Repo.update()

    # PubSub로 LiveView에 결과 전달
    Phoenix.PubSub.broadcast(
      InvoiceFlow.PubSub,
      PubSubTopics.extraction_completed(job.id),
      {:extraction_completed, extracted_data}
    )

    {:ok, updated_job}
  end

  @spec mark_failed(ExtractionJob.t(), String.t()) :: {:ok, ExtractionJob.t()}
  def mark_failed(%ExtractionJob{} = job, error_message) do
    job
    |> ExtractionJob.changeset(%{
      status: "failed",
      error_message: error_message,
      processing_completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  ## 추출 결과 → 송장 데이터 변환

  @spec to_invoice_attrs(map()) :: map()
  def to_invoice_attrs(extracted_data) do
    %{
      amount: parse_decimal(extracted_data["amount"]),
      currency: extracted_data["currency"] || "USD",
      due_date: parse_date(extracted_data["due_date"]),
      notes: extracted_data["notes"],
      items:
        (extracted_data["items"] || [])
        |> Enum.with_index()
        |> Enum.map(fn {item, idx} ->
          %{
            description: item["description"],
            quantity: parse_decimal(item["quantity"] || "1"),
            unit_price: parse_decimal(item["unit_price"]),
            position: idx
          }
        end)
    }
  end

  ## 추출 결과 → 클라이언트 매칭

  @spec find_or_suggest_client(binary(), map()) :: {:existing, Client.t()} | {:suggested, map()}
  def find_or_suggest_client(user_id, extracted_data) do
    email = extracted_data["client_email"]

    case email && InvoiceFlow.Clients.get_client_by_email(user_id, email) do
      %InvoiceFlow.Clients.Client{} = client ->
        {:existing, client}

      nil ->
        {:suggested, %{
          name: extracted_data["client_name"],
          email: email,
          company: extracted_data["client_company"]
        }}
    end
  end

  ## Private

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(String.replace(value, ~r/[,$]/, "")) do
      {decimal, _} -> decimal
      :error -> nil
    end
  end

  defp parse_date(nil), do: nil
  defp parse_date(value) when is_binary(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
```

---

## 4. Oban Worker

```elixir
defmodule InvoiceFlow.Workers.OcrExtractionWorker do
  use Oban.Worker,
    queue: :extraction,
    max_attempts: 3,
    priority: 1

  alias InvoiceFlow.Extraction
  alias InvoiceFlow.Extraction.AiClient

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"extraction_job_id" => job_id}}) do
    job = Extraction.get_job!(job_id)

    with {:ok, job} <- Extraction.mark_processing(job),
         {:ok, file_content} <- download_file(job.file_url),
         {:ok, raw_response} <- AiClient.extract_invoice_data(file_content, job.file_type),
         {:ok, extracted_data, confidence} <- parse_ai_response(raw_response) do
      Extraction.save_result(job, raw_response, extracted_data, confidence)
      :ok
    else
      {:error, reason} ->
        Extraction.mark_failed(job, inspect(reason))
        {:error, reason}
    end
  end

  defp download_file(url) do
    case Req.get(url) do
      {:ok, %{status: 200, body: body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, "Download failed: HTTP #{status}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_ai_response(response) do
    # AI 응답에서 구조화된 데이터와 신뢰도 추출
    extracted = response["extracted_data"]
    confidence = response["confidence"] || 0.5
    {:ok, extracted, confidence}
  end
end
```

---

## 5. AI Client (OpenAI GPT-4o Vision)

```elixir
defmodule InvoiceFlow.Extraction.AiClient do
  @moduledoc "OpenAI GPT-4o Vision API를 통한 송장 데이터 추출"

  @extraction_prompt """
  You are an invoice data extraction expert. Analyze the provided invoice image/PDF and extract the following information in JSON format:

  {
    "client_name": "string - client/customer name",
    "client_email": "string or null - client email if visible",
    "client_company": "string or null - client company name",
    "amount": "string - total amount as decimal (e.g., '1500.00')",
    "currency": "string - 3-letter currency code (USD, EUR, KRW, etc.)",
    "due_date": "string - due date in ISO 8601 format (YYYY-MM-DD)",
    "invoice_number": "string or null - existing invoice number if visible",
    "items": [
      {
        "description": "string - line item description",
        "quantity": "string - quantity as decimal",
        "unit_price": "string - unit price as decimal"
      }
    ],
    "notes": "string or null - any payment terms or notes",
    "confidence": 0.85
  }

  Be precise with amounts. If currency is ambiguous, default to USD.
  If a field is not visible, set it to null.
  The confidence score (0.0-1.0) should reflect how certain you are about the extraction.
  """

  @spec extract_invoice_data(binary(), String.t()) :: {:ok, map()} | {:error, term()}
  def extract_invoice_data(file_content, file_type) do
    base64_content = Base.encode64(file_content)
    media_type = media_type_for(file_type)

    body = %{
      model: "gpt-4o",
      messages: [
        %{
          role: "user",
          content: [
            %{type: "text", text: @extraction_prompt},
            %{
              type: "image_url",
              image_url: %{
                url: "data:#{media_type};base64,#{base64_content}",
                detail: "high"
              }
            }
          ]
        }
      ],
      max_tokens: 2000,
      response_format: %{type: "json_object"}
    }

    case Req.post(
      "https://api.openai.com/v1/chat/completions",
      json: body,
      headers: [
        {"authorization", "Bearer #{api_key()}"},
        {"content-type", "application/json"}
      ],
      receive_timeout: 60_000
    ) do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => %{"content" => content}} | _]}}} ->
        {:ok, Jason.decode!(content)}

      {:ok, %{status: status, body: body}} ->
        {:error, "OpenAI API error: #{status} - #{inspect(body)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp media_type_for("pdf"), do: "application/pdf"
  defp media_type_for(type) when type in ~w(jpg jpeg), do: "image/jpeg"
  defp media_type_for("png"), do: "image/png"

  defp api_key, do: Application.fetch_env!(:invoice_flow, :openai_api_key)
end
```

---

## 6. LiveView 플로우

### 6.1 업로드 → 추출 → 폼 자동 채움

```
[사용자: 송장 파일 드래그 앤 드롭]
│
├─ LiveView Upload 시작
│   └─ 프로그레스 바 표시 (0% → 100%)
│
├─ 업로드 완료
│   ├─ S3에 원본 저장 → file_url 획득
│   └─ Extraction.start_extraction(user_id, file_url, file_type)
│       └─ Oban Worker 큐잉
│
├─ 추출 중 (로딩 스피너 + "AI가 분석 중입니다...")
│   └─ PubSub 구독: extraction_completed(job_id)
│
├─ 추출 완료
│   ├─ {:extraction_completed, extracted_data} 수신
│   ├─ to_invoice_attrs(extracted_data) → 폼 자동 채움
│   ├─ find_or_suggest_client() → 클라이언트 자동 선택 or 제안
│   ├─ confidence_score 표시 (높음/보통/낮음 뱃지)
│   └─ 사용자가 수정 가능 (모든 필드 편집 가능)
│
└─ 추출 실패
    ├─ 에러 메시지 표시
    └─ 수동 입력 폼으로 폴백
```

### 6.2 신뢰도 UI

```
[신뢰도 뱃지]
├─ >= 0.8: 🟢 "높은 정확도" (초록 뱃지)
├─ >= 0.5: 🟡 "확인 필요" (노랑 뱃지)
└─ < 0.5:  🔴 "수동 검토 권장" (빨강 뱃지)
```

---

## 7. 테스트 시나리오

| # | 시나리오 | 타입 | 검증 항목 |
|---|----------|------|-----------|
| E-1 | 추출 작업 생성 | Unit | ExtractionJob 저장, status: pending |
| E-2 | PDF 파일 추출 성공 | Unit (Mock) | extracted_data 파싱, confidence 저장 |
| E-3 | JPG 이미지 추출 성공 | Unit (Mock) | 이미지 → base64 → AI 호출 |
| E-4 | AI API 실패 시 재시도 | Unit | Oban max_attempts 3회 재시도 |
| E-5 | 추출 실패 시 에러 저장 | Unit | status: failed, error_message 기록 |
| E-6 | extracted_data → invoice_attrs 변환 | Unit | 금액, 날짜, 항목 정확 변환 |
| E-7 | 금액 파싱 (콤마, $ 포함) | Unit | "$1,500.00" → Decimal(1500.00) |
| E-8 | 기존 클라이언트 매칭 | Unit | 이메일로 기존 Client 반환 |
| E-9 | 새 클라이언트 제안 | Unit | 매칭 없을 시 suggested 데이터 |
| E-10 | PubSub 결과 브로드캐스트 | Unit | extraction_completed 토픽 발행 |
| E-11 | LiveView 업로드 → 추출 → 폼 채움 | Integration | 전체 플로우 동작 |
| E-12 | 추출 실패 시 수동 입력 폴백 | Integration | 에러 표시 + 빈 폼 유지 |
