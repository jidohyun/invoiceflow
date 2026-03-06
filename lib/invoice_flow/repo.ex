defmodule InvoiceFlow.Repo do
  use Ecto.Repo,
    otp_app: :invoice_flow,
    adapter: Ecto.Adapters.Postgres
end
