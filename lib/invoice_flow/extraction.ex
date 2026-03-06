defmodule InvoiceFlow.Extraction do
  @moduledoc "AI OCR 송장 데이터 추출 Context"

  alias InvoiceFlow.Repo
  alias InvoiceFlow.Extraction.ExtractionJob
  alias InvoiceFlow.PubSubTopics

  ## 생성

  @spec create_job(binary(), map()) :: {:ok, ExtractionJob.t()} | {:error, Ecto.Changeset.t()}
  def create_job(user_id, attrs) do
    %ExtractionJob{user_id: user_id}
    |> ExtractionJob.changeset(attrs)
    |> Repo.insert()
  end

  ## 조회

  @spec get_job!(binary()) :: ExtractionJob.t()
  def get_job!(id), do: Repo.get!(ExtractionJob, id)

  @spec get_job_by_oban_id(integer()) :: ExtractionJob.t() | nil
  def get_job_by_oban_id(oban_job_id) do
    Repo.get_by(ExtractionJob, oban_job_id: oban_job_id)
  end

  ## 상태 전환

  @spec mark_processing(ExtractionJob.t()) :: {:ok, ExtractionJob.t()}
  def mark_processing(%ExtractionJob{} = job) do
    job
    |> ExtractionJob.changeset(%{
      status: "processing",
      processing_started_at: DateTime.truncate(DateTime.utc_now(), :second)
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
        processing_completed_at: DateTime.truncate(DateTime.utc_now(), :second)
      })
      |> Repo.update()

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
      processing_completed_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
    |> Repo.update()
  end

  ## 데이터 변환

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

  ## 클라이언트 매칭

  @spec find_or_suggest_client(binary(), map()) :: {:existing, struct()} | {:suggested, map()}
  def find_or_suggest_client(user_id, extracted_data) do
    email = extracted_data["client_email"]

    case email && InvoiceFlow.Clients.get_client_by_email(user_id, email) do
      %InvoiceFlow.Clients.Client{} = client ->
        {:existing, client}

      _ ->
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
