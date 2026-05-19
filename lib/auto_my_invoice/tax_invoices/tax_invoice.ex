defmodule AutoMyInvoice.TaxInvoices.TaxInvoice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(pending issued failed)

  schema "tax_invoices" do
    field :nts_confirm_no, :string
    field :status, :string, default: "pending"
    field :error_message, :string
    field :withholding_tax_amount, :decimal
    field :issued_at, :utc_datetime
    field :raw_response, :map

    belongs_to :invoice, AutoMyInvoice.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def statuses, do: @statuses

  def changeset(tax_invoice, attrs) do
    tax_invoice
    |> cast(attrs, [
      :invoice_id,
      :nts_confirm_no,
      :status,
      :error_message,
      :withholding_tax_amount,
      :issued_at,
      :raw_response
    ])
    |> validate_required([:invoice_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:invoice_id)
    |> unique_constraint(:invoice_id)
  end
end
