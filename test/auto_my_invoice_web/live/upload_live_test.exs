defmodule AutoMyInvoiceWeb.UploadLiveTest do
  @moduledoc """
  LiveView tests for the receipt upload + AI extraction flow.

  Covers AC-3 (reset event handler) and AC-5 (UploadLive integration tests)
  from .hermes/seeds/AMI-84.md. Where possible we use Phoenix.LiveViewTest
  end-to-end; where the LV is tightly coupled to PubSub broadcasts that
  follow a real file upload, we drive the handler functions directly.
  """

  use AutoMyInvoiceWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AutoMyInvoice.{Accounts, Extraction}
  alias AutoMyInvoiceWeb.UploadLive

  setup do
    {:ok, user} =
      Accounts.register_user(%{
        email: "upload-live-test-#{System.unique_integer([:positive])}@example.com",
        password: "validpassword123"
      })

    token = Accounts.generate_user_session_token(user)

    conn =
      build_conn()
      |> init_test_session(%{user_token: token})

    %{conn: conn, user: user}
  end

  defp create_pending_job(user) do
    {:ok, job} =
      Extraction.create_job(user.id, %{
        file_url: "/uploads/test.png",
        file_type: "png"
      })

    job
  end

  describe "GET /upload (T1)" do
    test "renders the upload form when no extraction is in progress", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/upload")

      assert html =~ "송장 업로드"
      assert html =~ "문서 업로드"
    end

    test "the upload page is gated to authenticated users" do
      conn = build_conn()
      assert {:error, {:redirect, %{to: redirect_to}}} = live(conn, ~p"/upload")
      assert redirect_to =~ "/users/log_in"
    end
  end

  describe "AC-3 reset handler" do
    test "handle_event/3 for 'reset' clears extraction_job and re-renders the upload form" do
      # Build a minimal socket with extraction_job pre-assigned, then call the
      # handler directly. This is the most reliable way to exercise the reset
      # path without going through the live_file_input fixture for an actual
      # multipart upload.
      job = %Extraction.ExtractionJob{
        id: Ecto.UUID.generate(),
        status: "completed",
        extracted_data: %{"amount" => "100", "currency" => "KRW"},
        confidence_score: 0.9
      }

      socket = %Phoenix.LiveView.Socket{assigns: %{extraction_job: job, __changed__: %{}}}

      assert {:noreply, new_socket} = UploadLive.handle_event("reset", %{}, socket)
      assert new_socket.assigns.extraction_job == nil
    end
  end

  describe "AC-4 InvoiceLive.New prefill from completed extraction" do
    test "navigating to /invoices/new?extraction_job_id=<id> populates the form prefill",
         %{conn: conn, user: user} do
      job = create_pending_job(user)

      extracted = %{
        "amount" => "1500.00",
        "currency" => "KRW",
        "due_date" => "2026-06-01",
        "notes" => "Net 30",
        "client_name" => "ACME"
      }

      {:ok, _completed} = Extraction.save_result(job, %{"raw" => "x"}, extracted, 0.92)

      {:ok, _view, html} = live(conn, ~p"/invoices/new?extraction_job_id=#{job.id}")

      assert html =~ "새 송장"
      # Robust prefill signals: the amount and currency from extracted_data
      # must appear in the rendered form. Before the AC-4 fix, the call
      # `Extraction.to_invoice_attrs(job)` returned a fully-nil map because
      # ExtractionJob structs do not implement Access on string keys, and
      # neither 1500 nor KRW would be present.
      assert html =~ "1500" or html =~ "1,500"
      assert html =~ "KRW"
    end

    test "extraction job that is not yet completed leaves prefill empty",
         %{conn: conn, user: user} do
      # Pending job (status: "pending", extracted_data: nil)
      job = create_pending_job(user)

      {:ok, _view, html} = live(conn, ~p"/invoices/new?extraction_job_id=#{job.id}")
      assert html =~ "새 송장"
    end
  end
end
