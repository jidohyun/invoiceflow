defmodule InvoiceFlow.Repo.Migrations.CreateInvoices do
  use Ecto.Migration

  def change do
    create table(:invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, references(:clients, type: :binary_id, on_delete: :restrict), null: false

      add :invoice_number, :string, null: false
      add :amount, :decimal, precision: 12, scale: 2, null: false
      add :currency, :string, default: "USD", null: false
      add :due_date, :date, null: false
      add :status, :string, default: "draft", null: false
      add :notes, :text

      add :pdf_url, :string
      add :original_file_url, :string

      add :paddle_payment_link, :string
      add :paid_at, :utc_datetime
      add :paid_amount, :decimal, precision: 12, scale: 2, default: 0

      add :sent_at, :utc_datetime
      add :overdue_notified_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invoices, [:invoice_number])
    create index(:invoices, [:user_id])
    create index(:invoices, [:client_id])
    create index(:invoices, [:status])
    create index(:invoices, [:due_date])
    create index(:invoices, [:user_id, :status])

    create table(:invoice_items, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all), null: false

      add :description, :string, null: false
      add :quantity, :decimal, precision: 10, scale: 2, default: 1
      add :unit_price, :decimal, precision: 12, scale: 2, null: false
      add :total, :decimal, precision: 12, scale: 2, null: false
      add :position, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:invoice_items, [:invoice_id])
  end
end
