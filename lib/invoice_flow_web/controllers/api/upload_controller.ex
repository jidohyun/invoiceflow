defmodule InvoiceFlowWeb.Api.UploadController do
  use InvoiceFlowWeb, :controller

  alias InvoiceFlow.Extraction
  alias InvoiceFlowWeb.Api.{JsonHelpers, FallbackController}

  action_fallback FallbackController

  def create(conn, %{"file" => %Plug.Upload{} = upload}) do
    user = conn.assigns.current_user

    attrs = %{
      original_filename: upload.filename,
      content_type: upload.content_type,
      file_path: upload.path,
      status: "pending"
    }

    case Extraction.create_job(user.id, attrs) do
      {:ok, job} ->
        # TODO: Enqueue Oban job for OCR processing
        conn
        |> put_status(:created)
        |> json(%{data: JsonHelpers.render_extraction_job(job)})

      error ->
        error
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "missing_file", message: "File upload is required"}})
  end

  def show(conn, %{"id" => id}) do
    job = Extraction.get_job!(id)
    json(conn, %{data: JsonHelpers.render_extraction_job(job)})
  rescue
    Ecto.NoResultsError -> {:error, :not_found}
  end
end
