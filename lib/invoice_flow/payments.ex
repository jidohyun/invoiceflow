defmodule InvoiceFlow.Payments do
  @moduledoc "결제 처리 및 Webhook 관리 Context"

  import Ecto.Query
  alias InvoiceFlow.Repo
  alias InvoiceFlow.Payments.{Payment, PaddleWebhookEvent}
  alias InvoiceFlow.Invoices
  alias InvoiceFlow.Invoices.Invoice
  alias InvoiceFlow.PubSubTopics

  ## 결제 완료 처리 (Webhook)

  @spec process_transaction_completed(map()) :: :ok | {:error, term()}
  def process_transaction_completed(data) do
    invoice_id = get_in(data, ["custom_data", "invoice_id"])

    with %Invoice{} = invoice <- Repo.get(Invoice, invoice_id),
         {:ok, _payment} <- create_payment(invoice, data),
         {:ok, invoice} <- Invoices.mark_as_paid(invoice) do
      Phoenix.PubSub.broadcast(
        InvoiceFlow.PubSub,
        PubSubTopics.payment_received(invoice.id),
        {:payment_received, invoice}
      )

      :ok
    else
      nil -> {:error, :invoice_not_found}
      error -> error
    end
  end

  ## Payment CRUD

  @spec create_payment(Invoice.t(), map()) :: {:ok, Payment.t()} | {:error, Ecto.Changeset.t()}
  def create_payment(invoice, webhook_data) do
    amount = get_in(webhook_data, ["details", "totals", "total"])
    currency = get_in(webhook_data, ["currency_code"])

    %Payment{invoice_id: invoice.id}
    |> Payment.changeset(%{
      paddle_transaction_id: webhook_data["id"],
      amount: parse_paddle_amount(amount),
      currency: currency,
      status: "completed",
      paid_at: DateTime.truncate(DateTime.utc_now(), :second),
      raw_webhook: webhook_data
    })
    |> Repo.insert()
  end

  @spec list_payments_for_invoice(binary()) :: [Payment.t()]
  def list_payments_for_invoice(invoice_id) do
    from(p in Payment,
      where: p.invoice_id == ^invoice_id,
      order_by: [desc: p.paid_at]
    )
    |> Repo.all()
  end

  ## Webhook 이벤트 로그

  @spec get_webhook_event(String.t()) :: PaddleWebhookEvent.t() | nil
  def get_webhook_event(event_id) do
    Repo.get_by(PaddleWebhookEvent, event_id: event_id)
  end

  @spec log_webhook_event(map()) :: {:ok, PaddleWebhookEvent.t()} | {:error, Ecto.Changeset.t()}
  def log_webhook_event(attrs) do
    %PaddleWebhookEvent{}
    |> PaddleWebhookEvent.changeset(attrs)
    |> Repo.insert()
  end

  @spec mark_event_processed(PaddleWebhookEvent.t()) :: {:ok, PaddleWebhookEvent.t()}
  def mark_event_processed(event) do
    event
    |> PaddleWebhookEvent.changeset(%{processed_at: DateTime.truncate(DateTime.utc_now(), :second)})
    |> Repo.update()
  end

  @spec mark_event_failed(PaddleWebhookEvent.t(), String.t()) :: {:ok, PaddleWebhookEvent.t()}
  def mark_event_failed(event, error_message) do
    event
    |> PaddleWebhookEvent.changeset(%{error_message: error_message})
    |> Repo.update()
  end

  ## Private

  defp parse_paddle_amount(nil), do: Decimal.new(0)

  defp parse_paddle_amount(amount) when is_binary(amount) do
    {cents, _} = Integer.parse(amount)
    Decimal.div(Decimal.new(cents), Decimal.new(100))
  end

  defp parse_paddle_amount(amount) when is_integer(amount) do
    Decimal.div(Decimal.new(amount), Decimal.new(100))
  end
end
