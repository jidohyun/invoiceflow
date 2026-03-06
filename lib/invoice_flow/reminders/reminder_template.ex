defmodule InvoiceFlow.Reminders.ReminderTemplate do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "reminder_templates" do
    field :step, :integer
    field :tone, :string
    field :subject_template, :string
    field :body_template, :string
    field :is_default, :boolean, default: false

    belongs_to :user, InvoiceFlow.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(template, attrs) do
    template
    |> cast(attrs, [:step, :tone, :subject_template, :body_template, :is_default, :user_id])
    |> validate_required([:step, :tone, :subject_template, :body_template])
    |> validate_inclusion(:step, [1, 2, 3])
    |> validate_inclusion(:tone, ~w(friendly gentle firm))
  end
end
