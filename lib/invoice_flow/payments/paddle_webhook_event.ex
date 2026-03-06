defmodule InvoiceFlow.Payments.PaddleWebhookEvent do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "paddle_webhook_events" do
    field :event_id, :string
    field :event_type, :string
    field :payload, :map
    field :processed_at, :utc_datetime
    field :error_message, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_id, :event_type, :payload, :processed_at, :error_message])
    |> validate_required([:event_id, :event_type, :payload])
    |> unique_constraint(:event_id)
  end
end
