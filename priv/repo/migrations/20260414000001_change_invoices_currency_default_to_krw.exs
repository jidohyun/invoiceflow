defmodule AutoMyInvoice.Repo.Migrations.ChangeInvoicesCurrencyDefaultToKrw do
  use Ecto.Migration

  def up do
    execute("ALTER TABLE invoices ALTER COLUMN currency SET DEFAULT 'KRW'")
  end

  def down do
    execute("ALTER TABLE invoices ALTER COLUMN currency SET DEFAULT 'USD'")
  end
end
