defmodule AutoMyInvoice.Invoices.Invoice do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ~w(draft sent overdue partially_paid paid cancelled)

  schema "invoices" do
    field :invoice_number, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :due_date, :date
    field :status, :string, default: "draft"
    field :notes, :string

    field :pdf_url, :string
    field :original_file_url, :string

    field :paddle_payment_link, :string
    field :paid_at, :utc_datetime
    field :paid_amount, :decimal, default: Decimal.new(0)

    field :sent_at, :utc_datetime
    field :overdue_notified_at, :utc_datetime

    belongs_to :user, AutoMyInvoice.Accounts.User
    belongs_to :client, AutoMyInvoice.Clients.Client

    has_many :items, AutoMyInvoice.Invoices.InvoiceItem, on_replace: :delete

    timestamps(type: :utc_datetime)
  end

  @required_fields [:amount, :currency, :due_date, :client_id]
  @optional_fields [
    :notes, :status, :pdf_url, :original_file_url,
    :paddle_payment_link, :paid_at, :paid_amount,
    :sent_at, :overdue_notified_at
  ]

  def create_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:currency, ~w(USD EUR KRW GBP JPY))
    |> validate_inclusion(:status, @statuses)
    |> validate_due_date_not_past()
    |> generate_invoice_number()
    |> cast_assoc(:items, with: &AutoMyInvoice.Invoices.InvoiceItem.changeset/2)
    |> foreign_key_constraint(:client_id)
  end

  def update_changeset(invoice, attrs) do
    invoice
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_number(:amount, greater_than: 0)
    |> validate_inclusion(:currency, ~w(USD EUR KRW GBP JPY))
    |> validate_inclusion(:status, @statuses)
    |> validate_status_transition()
    |> cast_assoc(:items, with: &AutoMyInvoice.Invoices.InvoiceItem.changeset/2)
  end

  def status_changeset(invoice, status) do
    invoice
    |> change(status: status)
    |> validate_inclusion(:status, @statuses)
    |> validate_status_transition()
  end

  def mark_paid_changeset(invoice, paid_at \\ DateTime.utc_now()) do
    invoice
    |> change(status: "paid", paid_at: paid_at, paid_amount: invoice.amount)
  end

  ## Private

  defp generate_invoice_number(changeset) do
    if get_field(changeset, :invoice_number) do
      changeset
    else
      now = Date.utc_today()
      prefix = "INV-#{Calendar.strftime(now, "%Y%m")}-"
      put_change(changeset, :invoice_number, prefix <> random_suffix())
    end
  end

  defp random_suffix do
    :crypto.strong_rand_bytes(2) |> Base.encode16() |> binary_part(0, 4)
  end

  defp validate_due_date_not_past(changeset) do
    due_date = get_change(changeset, :due_date)

    if due_date && Date.compare(due_date, Date.utc_today()) == :lt do
      add_error(changeset, :due_date, "마감일은 오늘 이후여야 합니다")
    else
      changeset
    end
  end

  @valid_transitions %{
    "draft" => ~w(sent cancelled),
    "sent" => ~w(overdue partially_paid paid cancelled),
    "overdue" => ~w(partially_paid paid cancelled),
    "partially_paid" => ~w(overdue paid cancelled),
    "paid" => [],
    "cancelled" => ["draft"]
  }

  defp validate_status_transition(changeset) do
    old_status = changeset.data.status
    new_status = get_change(changeset, :status)

    cond do
      is_nil(new_status) -> changeset
      is_nil(old_status) -> changeset
      new_status in Map.get(@valid_transitions, old_status, []) -> changeset
      true -> add_error(changeset, :status, "#{old_status}에서 #{new_status}로 전환할 수 없습니다")
    end
  end
end
