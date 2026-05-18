defmodule AutoMyInvoice.FxRatesStub do
  @moduledoc """
  Test-only FX rate client. Returns fixed quotes so tests are deterministic
  and don't hit the live API.

  Currencies & rates (1 unit of currency = N KRW) are loose 2026-05 ballpark:

      USD -> 1350
      EUR -> 1480
      JPY -> 9          # 1 JPY = 9 KRW (so 100 JPY ≈ 900 KRW)
      GBP -> 1720
  """

  @behaviour AutoMyInvoice.FxRates.Client

  @rates %{
    "USD" => Decimal.new("1350"),
    "EUR" => Decimal.new("1480"),
    "JPY" => Decimal.new("9"),
    "GBP" => Decimal.new("1720")
  }

  def stub_rates, do: @rates

  @impl true
  def fetch_rates(_base, targets) do
    {:ok, Map.take(@rates, targets)}
  end
end
