defmodule AutoMyInvoice.Repo.Migrations.CreateTaxInvoices do
  use Ecto.Migration

  def change do
    create table(:tax_invoices, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :invoice_id, references(:invoices, type: :binary_id, on_delete: :delete_all),
        null: false

      # National Tax Service confirmation number. Populated only when
      # status reaches "issued"; nil otherwise.
      add :nts_confirm_no, :string

      # one of: pending, issued, failed
      add :status, :string, null: false, default: "pending"
      add :error_message, :text

      # 3.3% local withholding tax computed at issue time (KRW).
      add :withholding_tax_amount, :decimal, precision: 18, scale: 2

      add :issued_at, :utc_datetime

      # Raw response from the Hometax API; useful for audit / debugging.
      add :raw_response, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tax_invoices, [:invoice_id])
    create index(:tax_invoices, [:status])
  end
end
