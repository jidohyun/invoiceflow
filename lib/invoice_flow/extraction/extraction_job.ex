defmodule InvoiceFlow.Extraction.ExtractionJob do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending processing completed failed)

  schema "extraction_jobs" do
    field :file_url, :string
    field :file_type, :string
    field :status, :string, default: "pending"
    field :error_message, :string

    field :raw_response, :map
    field :extracted_data, :map
    field :confidence_score, :float

    field :processing_started_at, :utc_datetime
    field :processing_completed_at, :utc_datetime
    field :oban_job_id, :integer

    belongs_to :user, InvoiceFlow.Accounts.User
    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(job, attrs) do
    job
    |> cast(attrs, [
      :file_url, :file_type, :status, :error_message,
      :raw_response, :extracted_data, :confidence_score,
      :processing_started_at, :processing_completed_at,
      :oban_job_id, :invoice_id
    ])
    |> validate_required([:file_url, :file_type])
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:file_type, ~w(pdf jpg jpeg png))
    |> validate_number(:confidence_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
  end
end
