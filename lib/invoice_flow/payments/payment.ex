defmodule InvoiceFlow.Payments.Payment do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(completed refunded disputed)

  schema "payments" do
    field :paddle_transaction_id, :string
    field :amount, :decimal
    field :currency, :string
    field :status, :string, default: "completed"
    field :paid_at, :utc_datetime
    field :raw_webhook, :map

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(payment, attrs) do
    payment
    |> cast(attrs, [:paddle_transaction_id, :amount, :currency, :status, :paid_at, :raw_webhook, :invoice_id])
    |> validate_required([:paddle_transaction_id, :amount, :status, :paid_at, :invoice_id])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> unique_constraint(:paddle_transaction_id)
  end
end
