defmodule AutoMyInvoice.FxRates.Client do
  @moduledoc "Behaviour for fetching FX rates. The test client implements this in-memory."

  @callback fetch_rates(base :: String.t(), targets :: [String.t()]) ::
              {:ok, %{String.t() => Decimal.t()}} | {:error, term()}
end

defmodule AutoMyInvoice.FxRates.HttpClient do
  @moduledoc """
  Live FX rate client backed by exchangerate.host (free, no key).

  The endpoint returns rates as "1 base = N target". We invert each pair so
  we end up with "1 target = M base" (i.e. how many KRW for 1 USD).
  """

  @behaviour AutoMyInvoice.FxRates.Client

  @endpoint "https://api.exchangerate.host/latest"

  @impl true
  def fetch_rates("KRW" = base, targets) do
    case Req.get(@endpoint, params: [base: base, symbols: Enum.join(targets, ",")]) do
      {:ok, %Req.Response{status: 200, body: %{"rates" => rates}}} ->
        {:ok, invert_rates(rates)}

      {:ok, %Req.Response{status: status, body: body}} ->
        {:error, {:http_status, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp invert_rates(rates) do
    Map.new(rates, fn {currency, rate_to_base} ->
      decimal = decimal_from(rate_to_base)
      # rate_to_base is "1 KRW = X currency", we want "1 currency = M KRW"
      inverted = Decimal.div(Decimal.new(1), decimal) |> Decimal.round(10)
      {currency, inverted}
    end)
  end

  defp decimal_from(n) when is_float(n), do: Decimal.from_float(n)
  defp decimal_from(n) when is_integer(n), do: Decimal.new(n)
  defp decimal_from(n) when is_binary(n), do: Decimal.new(n)
end
