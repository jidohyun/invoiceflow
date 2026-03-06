defmodule InvoiceFlow.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :name, :string, null: false
      add :email, :string, null: false
      add :company, :string
      add :phone, :string
      add :address, :text
      add :timezone, :string, default: "UTC"
      add :notes, :text

      add :avg_payment_days, :integer
      add :total_invoiced, :decimal, precision: 12, scale: 2, default: 0
      add :total_paid, :decimal, precision: 12, scale: 2, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:clients, [:user_id])
    create unique_index(:clients, [:user_id, :email])
  end
end
