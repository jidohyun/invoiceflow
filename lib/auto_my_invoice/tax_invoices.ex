defmodule AutoMyInvoice.TaxInvoices do
  @moduledoc """
  AMI-91 — Korean electronic tax invoice (전자세금계산서) issuance.

  Today the Hometax client is a deterministic stub (`StubClient`); the
  live client lands once we receive sandbox credentials.

  See `WithholdingCalculator` for the 3.3% local withholding rule.
  """

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.TaxInvoices.{TaxInvoice, WithholdingCalculator}

  @spec get_by_invoice(binary()) :: TaxInvoice.t() | nil
  def get_by_invoice(invoice_id) do
    Repo.get_by(TaxInvoice, invoice_id: invoice_id)
  end

  @doc """
  Idempotent — if a tax invoice already exists for `invoice`, return it
  unchanged. Otherwise call the Hometax client, persist the result, and
  return the new row.
  """
  @spec issue(map()) :: {:ok, TaxInvoice.t()} | {:error, term()}
  def issue(%{id: _id, currency: _currency} = invoice) do
    case get_by_invoice(invoice.id) do
      %TaxInvoice{status: "issued"} = existing ->
        {:ok, existing}

      _ ->
        do_issue(invoice)
    end
  end

  defp do_issue(invoice) do
    withholding = WithholdingCalculator.compute(invoice.amount, invoice.currency)

    case client().issue(invoice, []) do
      {:ok, %{nts_confirm_no: confirm, raw: raw}} ->
        attrs = %{
          invoice_id: invoice.id,
          nts_confirm_no: confirm,
          status: "issued",
          issued_at: DateTime.truncate(DateTime.utc_now(), :second),
          withholding_tax_amount: withholding,
          raw_response: raw,
          error_message: nil
        }

        upsert(invoice.id, attrs)

      {:error, reason} ->
        attrs = %{
          invoice_id: invoice.id,
          status: "failed",
          error_message: inspect(reason),
          withholding_tax_amount: withholding
        }

        upsert(invoice.id, attrs)
    end
  end

  defp upsert(invoice_id, attrs) do
    case get_by_invoice(invoice_id) do
      nil ->
        %TaxInvoice{}
        |> TaxInvoice.changeset(attrs)
        |> Repo.insert()

      %TaxInvoice{} = existing ->
        existing
        |> TaxInvoice.changeset(attrs)
        |> Repo.update()
    end
  end

  defp client do
    Application.get_env(:auto_my_invoice, __MODULE__, [])
    |> Keyword.get(:client, AutoMyInvoice.TaxInvoices.StubClient)
  end

  @doc "Outstanding (issued-but-unpaid) tax invoices for a user — surfaced by analytics."
  @spec issued_for_user(binary()) :: [TaxInvoice.t()]
  def issued_for_user(user_id) do
    from(ti in TaxInvoice,
      join: i in assoc(ti, :invoice),
      where: i.user_id == ^user_id and ti.status == "issued",
      preload: [:invoice]
    )
    |> Repo.all()
  end
end
