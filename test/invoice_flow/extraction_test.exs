defmodule InvoiceFlow.ExtractionTest do
  use InvoiceFlow.DataCase

  alias InvoiceFlow.Extraction
  alias InvoiceFlow.Extraction.ExtractionJob
  alias InvoiceFlow.Accounts
  alias InvoiceFlow.Clients

  defp create_user do
    {:ok, user} =
      Accounts.register_user(%{
        email: "ext-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    user
  end

  defp create_job(user, attrs \\ %{}) do
    default = %{file_url: "https://example.com/invoice.pdf", file_type: "pdf"}

    {:ok, job} =
      %ExtractionJob{user_id: user.id}
      |> ExtractionJob.changeset(Map.merge(default, attrs))
      |> Repo.insert()

    job
  end

  describe "ExtractionJob schema" do
    # E-1: 추출 작업 생성
    test "creates job with pending status" do
      user = create_user()
      job = create_job(user)

      assert job.status == "pending"
      assert job.file_url == "https://example.com/invoice.pdf"
      assert job.file_type == "pdf"
      assert job.user_id == user.id
    end

    test "validates required fields" do
      changeset = ExtractionJob.changeset(%ExtractionJob{}, %{})
      assert errors_on(changeset).file_url != []
      assert errors_on(changeset).file_type != []
    end

    test "validates file_type inclusion" do
      changeset = ExtractionJob.changeset(%ExtractionJob{}, %{file_url: "test.txt", file_type: "txt"})
      assert errors_on(changeset).file_type != []
    end

    test "validates confidence_score range" do
      changeset = ExtractionJob.changeset(%ExtractionJob{}, %{
        file_url: "test.pdf", file_type: "pdf", confidence_score: 1.5
      })
      assert errors_on(changeset).confidence_score != []
    end
  end

  describe "mark_processing/1" do
    # E-2 partial: 상태 전환
    test "changes status to processing and records start time" do
      user = create_user()
      job = create_job(user)

      assert {:ok, updated} = Extraction.mark_processing(job)
      assert updated.status == "processing"
      assert updated.processing_started_at != nil
    end
  end

  describe "save_result/4" do
    # E-2: 추출 성공 결과 저장
    test "saves extracted data with completed status" do
      user = create_user()
      job = create_job(user)

      raw = %{"choices" => [%{"text" => "data"}]}
      extracted = %{"amount" => "1500.00", "currency" => "USD"}

      assert {:ok, updated} = Extraction.save_result(job, raw, extracted, 0.95)
      assert updated.status == "completed"
      assert updated.raw_response == raw
      assert updated.extracted_data == extracted
      assert updated.confidence_score == 0.95
      assert updated.processing_completed_at != nil
    end

    # E-10: PubSub 결과 브로드캐스트
    test "broadcasts extraction_completed via PubSub" do
      user = create_user()
      job = create_job(user)

      topic = InvoiceFlow.PubSubTopics.extraction_completed(job.id)
      Phoenix.PubSub.subscribe(InvoiceFlow.PubSub, topic)

      extracted = %{"amount" => "1000.00"}
      {:ok, _} = Extraction.save_result(job, %{}, extracted, 0.8)

      assert_receive {:extraction_completed, ^extracted}
    end
  end

  describe "mark_failed/2" do
    # E-5: 추출 실패 시 에러 저장
    test "marks job as failed with error message" do
      user = create_user()
      job = create_job(user)

      assert {:ok, updated} = Extraction.mark_failed(job, "API timeout")
      assert updated.status == "failed"
      assert updated.error_message == "API timeout"
      assert updated.processing_completed_at != nil
    end
  end

  describe "to_invoice_attrs/1" do
    # E-6: extracted_data → invoice_attrs 변환
    test "converts extracted data to invoice attributes" do
      extracted = %{
        "amount" => "1500.00",
        "currency" => "EUR",
        "due_date" => "2026-04-15",
        "notes" => "Net 30",
        "items" => [
          %{"description" => "Web Design", "quantity" => "1", "unit_price" => "1000.00"},
          %{"description" => "Logo", "quantity" => "2", "unit_price" => "250.00"}
        ]
      }

      attrs = Extraction.to_invoice_attrs(extracted)
      assert Decimal.eq?(attrs.amount, Decimal.new("1500.00"))
      assert attrs.currency == "EUR"
      assert attrs.due_date == ~D[2026-04-15]
      assert attrs.notes == "Net 30"
      assert length(attrs.items) == 2
      assert Enum.at(attrs.items, 0).description == "Web Design"
      assert Enum.at(attrs.items, 1).position == 1
    end

    # E-7: 금액 파싱 (콤마, $ 포함)
    test "parses amounts with commas and dollar signs" do
      extracted = %{
        "amount" => "$1,500.00",
        "currency" => "USD",
        "due_date" => "2026-05-01",
        "items" => []
      }

      attrs = Extraction.to_invoice_attrs(extracted)
      assert Decimal.eq?(attrs.amount, Decimal.new("1500.00"))
    end

    test "handles nil values gracefully" do
      extracted = %{}
      attrs = Extraction.to_invoice_attrs(extracted)
      assert attrs.amount == nil
      assert attrs.currency == "USD"
      assert attrs.due_date == nil
      assert attrs.items == []
    end
  end

  describe "find_or_suggest_client/2" do
    # E-8: 기존 클라이언트 매칭
    test "returns existing client when email matches" do
      user = create_user()
      {:ok, client} = Clients.create_client(user.id, %{
        name: "Acme", email: "billing@acme.com", company: "Acme Corp"
      })

      extracted = %{"client_email" => "billing@acme.com", "client_name" => "Acme"}
      assert {:existing, found} = Extraction.find_or_suggest_client(user.id, extracted)
      assert found.id == client.id
    end

    # E-9: 새 클라이언트 제안
    test "suggests new client when no email match" do
      user = create_user()

      extracted = %{
        "client_email" => "new@company.com",
        "client_name" => "New Corp",
        "client_company" => "New Corporation"
      }

      assert {:suggested, suggestion} = Extraction.find_or_suggest_client(user.id, extracted)
      assert suggestion.name == "New Corp"
      assert suggestion.email == "new@company.com"
      assert suggestion.company == "New Corporation"
    end

    test "suggests when no email in extracted data" do
      user = create_user()
      extracted = %{"client_name" => "Unknown"}

      assert {:suggested, suggestion} = Extraction.find_or_suggest_client(user.id, extracted)
      assert suggestion.name == "Unknown"
      assert suggestion.email == nil
    end
  end

  describe "get_job!/1" do
    test "returns job by id" do
      user = create_user()
      job = create_job(user)

      found = Extraction.get_job!(job.id)
      assert found.id == job.id
    end
  end
end
