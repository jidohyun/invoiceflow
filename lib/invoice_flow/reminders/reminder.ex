defmodule InvoiceFlow.Reminders.Reminder do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @steps [1, 2, 3]
  @statuses ~w(pending scheduled sent cancelled failed)

  schema "reminders" do
    field :step, :integer
    field :scheduled_at, :utc_datetime
    field :sent_at, :utc_datetime
    field :status, :string, default: "pending"

    field :email_subject, :string
    field :email_body, :string

    field :opened_at, :utc_datetime
    field :clicked_at, :utc_datetime
    field :open_count, :integer, default: 0
    field :click_count, :integer, default: 0

    field :oban_job_id, :integer

    belongs_to :invoice, InvoiceFlow.Invoices.Invoice

    timestamps(type: :utc_datetime)
  end

  def changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [
      :step, :scheduled_at, :sent_at, :status,
      :email_subject, :email_body,
      :opened_at, :clicked_at, :open_count, :click_count,
      :oban_job_id
    ])
    |> validate_required([:step, :scheduled_at])
    |> validate_inclusion(:step, @steps)
    |> validate_inclusion(:status, @statuses)
  end

  def tracking_changeset(reminder, attrs) do
    reminder
    |> cast(attrs, [:opened_at, :clicked_at, :open_count, :click_count])
  end
end
