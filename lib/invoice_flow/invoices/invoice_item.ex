defmodule InvoiceFlow.Invoices.InvoiceItem do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "invoice_items" do
    field :description, :string
    field :quantity, :decimal, default: Decimal.new(1)
    field :unit_price, :decimal
    field :total, :decimal
    field :position, :integer

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:description, :quantity, :unit_price, :position])
    |> validate_required([:description, :quantity, :unit_price])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:unit_price, greater_than_or_equal_to: 0)
    |> calculate_total()
  end

  defp calculate_total(changeset) do
    quantity = get_field(changeset, :quantity) || Decimal.new(0)
    unit_price = get_field(changeset, :unit_price) || Decimal.new(0)
    put_change(changeset, :total, Decimal.mult(quantity, unit_price))
  end
end
