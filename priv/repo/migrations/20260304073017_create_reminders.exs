defmodule InvoiceFlow.Repo.Migrations.CreateReminders do
  use Ecto.Migration

  def change do
    create table(:reminders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :step, :integer, null: false
      add :scheduled_at, :utc_datetime, null: false
      add :sent_at, :utc_datetime
      add :status, :string, default: "pending", null: false

      add :email_subject, :text
      add :email_body, :text

      add :opened_at, :utc_datetime
      add :clicked_at, :utc_datetime
      add :open_count, :integer, default: 0
      add :click_count, :integer, default: 0

      add :oban_job_id, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:reminders, [:invoice_id])
    create index(:reminders, [:status])
    create index(:reminders, [:scheduled_at])
    create unique_index(:reminders, [:invoice_id, :step])

    create table(:reminder_templates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)

      add :step, :integer, null: false
      add :tone, :string, null: false
      add :subject_template, :text, null: false
      add :body_template, :text, null: false
      add :is_default, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:reminder_templates, [:user_id])
    create index(:reminder_templates, [:step, :is_default])
  end
end
