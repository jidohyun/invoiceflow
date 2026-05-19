defmodule AutoMyInvoice.TaxInvoices.HometaxClient do
  @moduledoc """
  Behaviour for issuing 전자세금계산서 via the Korean NTS (Hometax) API.

  Live integration is gated on a Hometax sandbox account + certificate
  bundle that we have not received yet — see Sprint 4 kickoff notes.
  Until that lands, the system runs against `StubClient`, which fakes a
  successful issue + confirmation number deterministically so the rest
  of the pipeline (DB writes, UI flow, withholding calculation, send
  hook) can be developed and regression-tested end-to-end.
  """

  @callback issue(invoice :: map(), opts :: keyword()) ::
              {:ok, %{nts_confirm_no: String.t(), raw: map()}} | {:error, term()}
end

defmodule AutoMyInvoice.TaxInvoices.StubClient do
  @moduledoc """
  Deterministic stand-in for the Hometax client. Generates a synthetic
  NTS confirmation number `STUB-<invoice-id-prefix>-<unix>` and never
  actually contacts an external system.

  When the real client lands, swap via:

      config :auto_my_invoice, AutoMyInvoice.TaxInvoices,
        client: AutoMyInvoice.TaxInvoices.LiveClient

  The stub is wired in `config :auto_my_invoice, AutoMyInvoice.TaxInvoices,
  client: AutoMyInvoice.TaxInvoices.StubClient` (the default).
  """

  @behaviour AutoMyInvoice.TaxInvoices.HometaxClient

  @impl true
  def issue(%{id: invoice_id} = invoice, _opts) do
    confirm_no =
      "STUB-#{String.slice(invoice_id, 0, 8)}-#{System.system_time(:second)}"

    {:ok,
     %{
       nts_confirm_no: confirm_no,
       raw: %{
         "stub" => true,
         "issued_at" => DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
         "invoice_number" => Map.get(invoice, :invoice_number),
         "supplier_id" => Map.get(invoice, :user_id),
         "customer_id" => Map.get(invoice, :client_id)
       }
     }}
  end
end
