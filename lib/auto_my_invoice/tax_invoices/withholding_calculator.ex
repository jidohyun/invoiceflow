defmodule AutoMyInvoice.TaxInvoices.WithholdingCalculator do
  @moduledoc """
  Korean 3.3% withholding tax on freelance income (사업소득 원천징수).

  Breakdown:
    * 3.0% national income tax (소득세)
    * 0.3% local income tax (지방소득세 — 소득세 × 10%)

  By convention, the withheld amount is rounded down to the won (no
  sub-won fractions on invoices). KRW invoices are the only case we
  apply the standard 3.3% rate; for non-KRW invoices we leave the
  decision to the caller — Korean withholding only applies to amounts
  paid in KRW.

  Returns a `Decimal` with `scale = 0` (whole won).
  """

  @rate Decimal.new("0.033")

  @spec rate() :: Decimal.t()
  def rate, do: @rate

  @spec compute(Decimal.t() | number(), String.t()) :: Decimal.t()
  def compute(amount, currency \\ "KRW")

  def compute(amount, "KRW") do
    amount
    |> to_decimal()
    |> Decimal.mult(@rate)
    |> Decimal.round(0, :floor)
  end

  # No standard Korean withholding for non-KRW invoices.
  def compute(_amount, _currency), do: Decimal.new(0)

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(n) when is_binary(n), do: Decimal.new(n)
end
