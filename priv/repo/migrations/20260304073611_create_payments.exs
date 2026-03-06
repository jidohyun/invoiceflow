defmodule InvoiceFlow.Repo.Migrations.CreatePayments do
  use Ecto.Migration

  def change do
    create table(:payments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :restrict), null: false

      add :paddle_transaction_id, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string
      add :status, :string, default: "completed", null: false
      add :paid_at, :utc_datetime, null: false
      add :raw_webhook, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payments, [:paddle_transaction_id])
    create index(:payments, [:invoice_id])

    create table(:paddle_webhook_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :event_id, :string, null: false
      add :event_type, :string, null: false
      add :payload, :map, null: false
      add :processed_at, :utc_datetime
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:paddle_webhook_events, [:event_id])

    create table(:subscriptions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :paddle_subscription_id, :string, null: false
      add :paddle_customer_id, :string
      add :plan, :string, null: false
      add :status, :string, default: "active", null: false
      add :current_period_start, :utc_datetime
      add :current_period_end, :utc_datetime
      add :cancelled_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:subscriptions, [:paddle_subscription_id])
    create index(:subscriptions, [:user_id])
    create index(:subscriptions, [:status])
  end
end
