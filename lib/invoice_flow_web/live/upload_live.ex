defmodule InvoiceFlowWeb.UploadLive do
  use InvoiceFlowWeb, :live_view

  alias InvoiceFlow.{Extraction, PubSubTopics}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Upload Invoice")
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

  @impl true
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
            InvoiceFlow.PubSub,
            PubSubTopics.extraction_completed(job.id)
          )
        end

        {:noreply,
         socket
         |> assign(:extraction_job, job)
         |> put_flash(:info, "File uploaded. Processing...")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Upload failed")}
    end
  end

  @impl true
  def handle_info({:extraction_completed, job}, socket) do
    {:noreply,
     socket
     |> assign(:extraction_job, job)
     |> put_flash(:info, "Extraction complete!")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="Upload Invoice" />

    <div class="max-w-2xl">
      <%= if @extraction_job == nil do %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">Upload a Document</h2>
            <p class="text-base-content/60 mb-4">
              Upload a PDF or image of an invoice. AI will extract the details automatically.
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
                    aria-label="cancel"
                  >
                    <.icon name="hero-x-mark" class="size-4" />
                  </button>
                </div>

                <div :for={err <- upload_errors(@uploads.invoice_file, entry)} class="text-error text-sm mt-1">
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
                <.icon name="hero-arrow-up-tray" class="size-4" /> Upload & Extract
              </button>
            </form>
          </div>
        </div>
      <% else %>
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <h2 class="card-title text-lg">Extraction Status</h2>

            <div class="mt-4">
              <%= case @extraction_job.status do %>
                <% s when s in ~w(pending processing) -> %>
                  <div class="flex items-center gap-3">
                    <span class="loading loading-spinner loading-md text-primary"></span>
                    <span class="text-base-content/60">Processing document...</span>
                  </div>

                <% "completed" -> %>
                  <div class="alert alert-success mb-4">
                    <.icon name="hero-check-circle" class="size-5" />
                    <span>Extraction complete! Review the results below.</span>
                  </div>

                  <div :if={@extraction_job.extracted_data} class="space-y-3">
                    <div :for={{key, value} <- @extraction_job.extracted_data} class="flex justify-between border-b border-base-200 pb-2">
                      <span class="text-sm text-base-content/60 capitalize">{humanize_key(key)}</span>
                      <span class="font-medium">{format_value(value)}</span>
                    </div>
                  </div>

                  <div :if={@extraction_job.confidence_score} class="mt-3">
                    <span class="text-sm text-base-content/60">Confidence</span>
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
                      <.icon name="hero-document-plus" class="size-4" /> Create Invoice
                    </.link>
                    <button class="btn btn-ghost" phx-click="reset" phx-target="">
                      Upload Another
                    </button>
                  </div>

                <% "failed" -> %>
                  <div class="alert alert-error">
                    <.icon name="hero-x-circle" class="size-5" />
                    <span>Extraction failed: {@extraction_job.error_message || "Unknown error"}</span>
                  </div>
                  <button class="btn btn-ghost mt-4" phx-click="reset">
                    Try Again
                  </button>
              <% end %>
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "Invalid file type. Use PDF, JPG, or PNG"
  defp error_to_string(:too_many_files), do: "Only one file at a time"
  defp error_to_string(err), do: "Error: #{inspect(err)}"

  defp humanize_key(key) when is_binary(key) do
    key |> String.replace("_", " ")
  end

  defp format_value(value) when is_list(value), do: Enum.join(value, ", ")
  defp format_value(value) when is_map(value), do: Jason.encode!(value)
  defp format_value(value), do: to_string(value)

  defp confidence_class(score) when score >= 0.8, do: "progress-success"
  defp confidence_class(score) when score >= 0.5, do: "progress-warning"
  defp confidence_class(_), do: "progress-error"
end
