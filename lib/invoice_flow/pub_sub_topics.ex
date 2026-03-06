defmodule InvoiceFlow.PubSubTopics do
  @moduledoc "PubSub 토픽 이름 중앙 관리"

  def invoice_updated(invoice_id), do: "invoice:#{invoice_id}"
  def user_invoices(user_id), do: "user:#{user_id}:invoices"
  def extraction_completed(job_id), do: "extraction:#{job_id}"
  def payment_received(invoice_id), do: "payment:#{invoice_id}"
end
