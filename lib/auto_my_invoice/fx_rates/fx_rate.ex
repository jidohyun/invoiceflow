defmodule AutoMyInvoice.FxRates.FxRate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "fx_rates" do
    field :base, :string
    field :quote, :string
    field :rate, :decimal
    field :fetched_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(fx_rate, attrs) do
    fx_rate
    |> cast(attrs, [:base, :quote, :rate, :fetched_at])
    |> validate_required([:base, :quote, :rate, :fetched_at])
    |> validate_length(:base, is: 3)
    |> validate_length(:quote, is: 3)
    |> unique_constraint([:base, :quote])
  end
end
