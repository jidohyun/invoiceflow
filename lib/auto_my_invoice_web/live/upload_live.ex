defmodule AutoMyInvoiceWeb.UploadLive do
  use AutoMyInvoiceWeb, :live_view

  alias AutoMyInvoice.{Extraction, PubSubTopics}
  alias AutoMyInvoice.Workers.OcrExtractionWorker

  @max_entries 10

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "송장 업로드")
     |> assign(:extraction_jobs, [])
     |> allow_upload(:invoice_file,
       accept: ~w(.pdf .jpg .jpeg .png),
       max_file_size: 10_000_000,
       max_entries: @max_entries
     )}
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("reset", _params, socket) do
    # Clear the visible job list and return to the upload form. The
    # ExtractionJob rows are intentionally NOT deleted — historical jobs
    # remain queryable for analytics and audit.
    {:noreply, assign(socket, :extraction_jobs, [])}
  end

  def handle_event("dismiss-job", %{"id" => job_id}, socket) do
    jobs = Enum.reject(socket.assigns.extraction_jobs, &(&1.id == job_id))
    {:noreply, assign(socket, :extraction_jobs, jobs)}
  end

  def handle_event("upload", _params, socket) do
    user = socket.assigns.current_user

    results =
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

        {:ok,
         %{
           file_url: "/uploads/#{Path.basename(dest)}",
           file_type: file_type,
           file_name: entry.client_name
         }}
      end)

    {jobs, errors} =
      Enum.reduce(results, {[], []}, fn result, {jobs_acc, err_acc} ->
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

            # Stash the user-facing filename on the in-memory struct so the UI
            # can show which file each job came from. The DB column doesn't
            # need it.
            job = Map.put(job, :__file_name__, result.file_name)
            {[job | jobs_acc], err_acc}

          {:error, _changeset} ->
            {jobs_acc, [result.file_name | err_acc]}
        end
      end)

    new_jobs = socket.assigns.extraction_jobs ++ Enum.reverse(jobs)

    socket =
      socket
      |> assign(:extraction_jobs, new_jobs)
      |> maybe_flash_upload_result(length(jobs), errors)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:extraction_completed, _extracted_data}, socket) do
    # We don't know which job fired from the payload alone, so refresh every
    # in-flight job. With max 10 jobs this is a trivial number of queries.
    refreshed =
      Enum.map(socket.assigns.extraction_jobs, fn job ->
        latest = Extraction.get_job!(job.id)
        Map.put(latest, :__file_name__, Map.get(job, :__file_name__))
      end)

    {:noreply, assign(socket, :extraction_jobs, refreshed)}
  end

  defp maybe_flash_upload_result(socket, success_count, []) when success_count > 0 do
    put_flash(socket, :info, "#{success_count}개 파일이 업로드되었습니다. 처리 중...")
  end

  defp maybe_flash_upload_result(socket, success_count, errors) when success_count > 0 do
    put_flash(
      socket,
      :warning,
      "#{success_count}개 업로드 성공, #{length(errors)}개 실패: #{Enum.join(errors, ", ")}"
    )
  end

  defp maybe_flash_upload_result(socket, 0, errors) do
    put_flash(socket, :error, "업로드 실패: #{Enum.join(errors, ", ")}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="송장 업로드" />

    <div class="max-w-3xl space-y-6">
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <h2 class="card-title text-lg">문서 업로드</h2>
          <p class="text-base-content/60 mb-4">
            송장 PDF나 이미지를 한 번에 최대 10개까지 업로드하면 AI가 자동으로 내용을 추출합니다.
          </p>

          <form id="upload-form" phx-submit="upload" phx-change="validate">
            <.upload_zone upload={@uploads.invoice_file} />

            <div :for={entry <- @uploads.invoice_file.entries} class="mt-4">
              <div class="flex items-center gap-3">
                <span class="text-sm font-medium truncate flex-1">{entry.client_name}</span>
                <progress class="progress progress-primary w-32" value={entry.progress} max="100">
                  {entry.progress}%
                </progress>
                <span class="text-sm text-base-content/60 w-12 text-right">{entry.progress}%</span>
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

      <div :if={@extraction_jobs != []} class="space-y-4">
        <div class="flex items-center justify-between">
          <h2 class="text-lg font-medium">처리 결과 ({length(@extraction_jobs)})</h2>
          <button type="button" class="btn btn-ghost btn-sm" phx-click="reset">
            전체 비우기
          </button>
        </div>

        <div
          :for={job <- @extraction_jobs}
          class="card bg-base-100 shadow"
          id={"job-#{job.id}"}
        >
          <div class="card-body p-4">
            <div class="flex items-start justify-between gap-3">
              <div class="min-w-0 flex-1">
                <p class="font-medium truncate">
                  {Map.get(job, :__file_name__) || job.file_url}
                </p>
                <p class="text-xs text-base-content/60">{status_label(job.status)}</p>
              </div>
              <button
                type="button"
                class="btn btn-ghost btn-xs btn-circle"
                phx-click="dismiss-job"
                phx-value-id={job.id}
                aria-label="이 결과 숨기기"
              >
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </div>

            <div class="mt-3">
              <%= case job.status do %>
                <% s when s in ~w(pending processing) -> %>
                  <div class="flex items-center gap-3">
                    <span class="loading loading-spinner loading-sm text-primary"></span>
                    <span class="text-base-content/60 text-sm">문서 처리 중...</span>
                  </div>
                <% "completed" -> %>
                  <div :if={job.confidence_score} class="mb-3">
                    <div class="flex items-center justify-between text-xs text-base-content/60 mb-1">
                      <span>신뢰도</span>
                      <span>{round(job.confidence_score * 100)}%</span>
                    </div>
                    <progress
                      class={"progress #{confidence_class(job.confidence_score)} w-full"}
                      value={round(job.confidence_score * 100)}
                      max="100"
                    />
                  </div>

                  <div :if={job.extracted_data} class="space-y-1 text-sm">
                    <div
                      :for={{key, value} <- job.extracted_data}
                      class="flex justify-between border-b border-base-200 pb-1"
                    >
                      <span class="text-base-content/60">{humanize_key(key)}</span>
                      <span class="font-medium truncate ml-2 text-right">
                        {format_value(value)}
                      </span>
                    </div>
                  </div>

                  <.link
                    navigate={~p"/invoices/new?extraction_job_id=#{job.id}"}
                    class="btn btn-primary btn-sm mt-3"
                  >
                    <.icon name="hero-document-plus" class="size-4" /> 송장 생성
                  </.link>
                <% "failed" -> %>
                  <div class="alert alert-error py-2">
                    <.icon name="hero-x-circle" class="size-5" />
                    <span class="text-sm">
                      추출 실패: {job.error_message || "알 수 없는 오류"}
                    </span>
                  </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "파일이 너무 큽니다 (최대 10MB)"
  defp error_to_string(:not_accepted), do: "지원되지 않는 파일 형식입니다. PDF, JPG, PNG만 가능"
  defp error_to_string(:too_many_files), do: "한 번에 최대 #{@max_entries}개의 파일만 업로드할 수 있습니다"
  defp error_to_string(err), do: "오류: #{inspect(err)}"

  defp status_label("pending"), do: "대기 중"
  defp status_label("processing"), do: "처리 중"
  defp status_label("completed"), do: "완료"
  defp status_label("failed"), do: "실패"
  defp status_label(other), do: other

  defp humanize_key("amount"), do: "금액"
  defp humanize_key("currency"), do: "통화"
  defp humanize_key("due_date"), do: "지급 기한"
  defp humanize_key("notes"), do: "메모"
  defp humanize_key("invoice_number"), do: "송장 번호"
  defp humanize_key("items"), do: "품목"
  defp humanize_key("client_name"), do: "거래처명"
  defp humanize_key("client_email"), do: "거래처 이메일"
  defp humanize_key(key) when is_binary(key), do: String.replace(key, "_", " ")

  defp format_value(value) when is_list(value), do: "#{length(value)}개"
  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value), do: to_string(value)

  defp confidence_class(score) when score >= 0.8, do: "progress-success"
  defp confidence_class(score) when score >= 0.5, do: "progress-warning"
  defp confidence_class(_), do: "progress-error"
end
