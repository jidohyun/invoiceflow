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
