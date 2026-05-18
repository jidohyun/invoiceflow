defmodule AutoMyInvoice.Repo.Migrations.AddFxRatesAndAmountKrw do
  use Ecto.Migration

  def change do
    create table(:fx_rates, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :base, :string, null: false, size: 3
      add :quote, :string, null: false, size: 3
      add :rate, :decimal, precision: 20, scale: 10, null: false
      add :fetched_at, :utc_datetime, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:fx_rates, [:base, :quote])

    # KRW-equivalent cached on every invoice so dashboard/analytics can sum
    # across currencies without joining fx_rates on every query.
    alter table(:invoices) do
      add :amount_krw, :decimal, precision: 18, scale: 2
    end

    create index(:invoices, [:user_id, :status, :amount_krw])
  end
end
