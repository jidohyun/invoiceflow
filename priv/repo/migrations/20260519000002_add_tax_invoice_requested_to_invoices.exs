defmodule AutoMyInvoice.Repo.Migrations.AddTaxInvoiceRequestedToInvoices do
  use Ecto.Migration

  def change do
    alter table(:invoices) do
      # AMI-91: merchant ticks "세금계산서 동시 발행" on the invoice form;
      # send_invoice/1 reads this flag and (idempotently) issues a tax
      # invoice via the Hometax stub client.
      add :tax_invoice_requested, :boolean, null: false, default: false
    end
  end
end
