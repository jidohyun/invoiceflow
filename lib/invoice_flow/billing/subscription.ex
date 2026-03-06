defmodule InvoiceFlow.Billing.Subscription do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(active past_due cancelled paused)

  schema "subscriptions" do
    field :paddle_subscription_id, :string
    field :paddle_customer_id, :string
    field :plan, :string
    field :status, :string, default: "active"
    field :current_period_start, :utc_datetime
    field :current_period_end, :utc_datetime
    field :cancelled_at, :utc_datetime

    belongs_to :user, InvoiceFlow.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(subscription, attrs) do
    subscription
    |> cast(attrs, [:paddle_subscription_id, :paddle_customer_id, :plan,
                     :status, :current_period_start, :current_period_end, :cancelled_at])
    |> validate_required([:paddle_subscription_id, :plan, :status])
    |> validate_inclusion(:plan, ~w(starter pro))
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:paddle_subscription_id)
  end
end
