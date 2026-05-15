defmodule AutoMyInvoiceWeb.UploadLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Extraction, PubSubTopics}
  alias AutoMyInvoice.Workers.OcrExtractionWorker

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "송장 업로드")
     |> assign(:extraction_job, nil)
     |> allow_upload(:invoice_file,
       accept: ~w(.pdf .jpg .jpeg .png),
       max_file_size: 10_000_000,
       max_entries: 1
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    # Allow the user to discard the current ExtractionJob view and return to
    # the upload form so they can start over (e.g. after a low-confidence
    # extraction or a failure). The ExtractionJob row is intentionally NOT
    # deleted — historical jobs remain queryable for analytics and audit.
    {:noreply, assign(socket, :extraction_job, nil)}
  end

  def handle_event("upload", _params, socket) do
    user = socket.assigns.current_user

    [result] =
      consume_uploaded_entries(socket, :invoice_file, fn %{path: path}, entry ->
        file_type =
          case entry.client_type do
            "application/pdf" -> "pdf"
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            _ -> "unknown"
          end

        dest = Path.join(["priv", "static", "uploads", "#{Ecto.UUID.generate()}.#{file_type}"])
        File.mkdir_p!(Path.dirname(dest))
        File.cp!(path, dest)

        {:ok, %{file_url: "/uploads/#{Path.basename(dest)}", file_type: file_type}}
      end)

    case Extraction.create_job(user.id, %{
           file_url: result.file_url,
           file_type: result.file_type
         }) do
      {:ok, job} ->
        if connected?(socket) do
          Phoenix.PubSub.subscribe(
            AutoMyInvoice.PubSub,
            PubSubTopics.extraction_completed(job.id)
          )
        end

        {:ok, oban_job} =
          %{extraction_job_id: job.id}
          |> OcrExtractionWorker.new()
          |> Oban.insert()

        {:ok, job} =
          job
          |> Extraction.ExtractionJob.changeset(%{oban_job_id: oban_job.id})
          |> AutoMyInvoice.Repo.update()

        {:noreply,
         socket
         |> assign(:extraction_job, job)
         |> put_flash(:info, "파일이 업로드되었습니다. 처리 중...")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "업로드에 실패했습니다")}
    end
  end

  @impl true
  def handle_info({:extraction_completed, _extracted_data}, socket) do
    job = Extraction.get_job!(socket.assigns.extraction_job.id)

    {:noreply,
     socket
     |> assign(:extraction_job, job)
     |> put_flash(:info, "추출이 완료되었습니다!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="송장 업로드" />

    <div class="max-w-2xl">
      <%= if @extraction_job == nil do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">문서 업로드</h2>
            <p class="text-base-content/60 mb-4">
              송장 PDF나 이미지를 업로드하면 AI가 자동으로 내용을 추출합니다.
            </p>

            <form id="upload-form" phx-submit="upload" phx-change="validate">
              <.upload_zone upload={@uploads.invoice_file} />

              <div :for={entry <- @uploads.invoice_file.entries} class="mt-4">
                <div class="flex items-center gap-3">
                  <span class="text-sm font-medium">{entry.client_name}</span>
                  <progress class="progress progress-primary flex-1" value={entry.progress} max="100">
                    {entry.progress}%
                  </progress>
                  <span class="text-sm text-base-content/60">{entry.progress}%</span>
                  <button
                    type="button"
                    class="btn btn-ghost btn-xs btn-circle"
                    phx-click="cancel-upload"
                    phx-value-ref={entry.ref}
                    aria-label="취소"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>

                <div
                  :for={err <- upload_errors(@uploads.invoice_file, entry)}
                  class="text-error text-sm mt-1"
                >
                  {error_to_string(err)}
                </div>
              </div>

              <div :for={err <- upload_errors(@uploads.invoice_file)} class="text-error text-sm mt-2">
                {error_to_string(err)}
              </div>

              <button
                type="submit"
                class="btn btn-primary mt-4"
                disabled={@uploads.invoice_file.entries == []}
              >
                <.icon name="hero-arrow-up-tray" class="size-4" /> 업로드 & 추출
              </button>
            </form>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">추출 상태</h2>

            <div class="mt-4">
              <%= case @extraction_job.status do %>
                <% s when s in ~w(pending processing) -> %>
                  <div class="flex items-center gap-3">
                    <span class="loading loading-spinner loading-md text-primary"></span>
                    <span class="text-base-content/60">문서 처리 중...</span>
                  </div>
                <% "completed" -> %>
                  <div class="alert alert-success mb-4">
                    <.icon name="hero-check-circle" class="size-5" />
                    <span>추출이 완료되었습니다! 아래 결과를 확인하세요.</span>
                  </div>

                  <div :if={@extraction_job.extracted_data} class="space-y-3">
                    <div
                      :for={{key, value} <- @extraction_job.extracted_data}
                      class="flex justify-between border-b border-base-200 pb-2"
                    >
                      <span class="text-sm text-base-content/60">{humanize_key(key)}</span>
                      <span class="font-medium">{format_value(value)}</span>
                    </div>
                  </div>

                  <div :if={@extraction_job.confidence_score} class="mt-3">
                    <span class="text-sm text-base-content/60">신뢰도</span>
                    <progress
                      class={"progress #{confidence_class(@extraction_job.confidence_score)} w-full"}
                      value={round(@extraction_job.confidence_score * 100)}
                      max="100"
                    />
                    <span class="text-sm">{round(@extraction_job.confidence_score * 100)}%</span>
                  </div>

                  <div class="flex gap-2 mt-6">
                    <.link
                      navigate={~p"/invoices/new?extraction_job_id=#{@extraction_job.id}"}
                      class="btn btn-primary"
                    >
                      <.icon name="hero-document-plus" class="size-4" /> 송장 생성
                    </.link>
                    <button type="button" class="btn btn-ghost" phx-click="reset">
                      다른 파일 업로드
                    </button>
                  </div>
                <% "failed" -> %>
                  <div class="alert alert-error">
                    <.icon name="hero-x-circle" class="size-5" />
                    <span>추출 실패: {@extraction_job.error_message || "알 수 없는 오류"}</span>
                  </div>
                  <button type="button" class="btn btn-ghost mt-4" phx-click="reset">
                    다시 시도
                  </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "파일이 너무 큽니다 (최대 10MB)"
  defp error_to_string(:not_accepted), do: "지원되지 않는 파일 형식입니다. PDF, JPG, PNG만 가능"
  defp error_to_string(:too_many_files), do: "한 번에 하나의 파일만 업로드할 수 있습니다"
  defp error_to_string(err), do: "오류: #{inspect(err)}"

  defp humanize_key("amount"), do: "금액"
  defp humanize_key("currency"), do: "통화"
  defp humanize_key("due_date"), do: "지급 기한"
  defp humanize_key("notes"), do: "메모"
  defp humanize_key("invoice_number"), do: "송장 번호"
  defp humanize_key("items"), do: "품목"
  defp humanize_key("client_name"), do: "거래처명"
  defp humanize_key("client_email"), do: "거래처 이메일"
  defp humanize_key(key) when is_binary(key), do: String.replace(key, "_", " ")

  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value), do: to_string(value)

  defp confidence_class(score) when score >= 0.8, do: "progress-success"
  defp confidence_class(score) when score >= 0.5, do: "progress-warning"
  defp confidence_class(_), do: "progress-error"
end
