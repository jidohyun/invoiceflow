defmodule AutoMyInvoice.FxRates do
  @moduledoc """
  Foreign-exchange rate context. Quotes are stored to KRW so the dashboard
  and analytics can sum invoices across currencies with a single CAST.

  The HTTP client is pluggable so tests don't hit the live API:

      config :auto_my_invoice, AutoMyInvoice.FxRates,
        client: AutoMyInvoice.FxRates.HttpClient

  Identity rate (KRW→KRW) is always 1.0 and never round-trips through the
  API.
  """

  import Ecto.Query
  alias AutoMyInvoice.Repo
  alias AutoMyInvoice.FxRates.FxRate

  @base_currency "KRW"

  @doc "The base currency every rate quotes against."
  def base_currency, do: @base_currency

  @doc """
  Convert `amount` from `from_currency` to KRW using the latest cached rate.
  Returns `{:ok, decimal}` or `{:error, :missing_rate}` when we don't have
  a cached rate for that currency yet.
  """
  @spec to_krw(Decimal.t() | number(), String.t()) ::
          {:ok, Decimal.t()} | {:error, :missing_rate}
  def to_krw(amount, currency)

  def to_krw(amount, @base_currency), do: {:ok, to_decimal(amount)}

  def to_krw(amount, currency) when is_binary(currency) do
    case latest_rate(currency) do
      %FxRate{rate: rate} ->
        {:ok, amount |> to_decimal() |> Decimal.mult(rate) |> Decimal.round(2)}

      nil ->
        {:error, :missing_rate}
    end
  end

  @doc """
  Look up the most recent quote for `currency` against KRW.
  """
  @spec latest_rate(String.t()) :: FxRate.t() | nil
  def latest_rate(currency) when is_binary(currency) do
    Repo.get_by(FxRate, base: currency, quote: @base_currency)
  end

  @doc """
  Insert or update one rate (currency → KRW).
  """
  @spec upsert_rate(String.t(), Decimal.t() | number(), DateTime.t()) ::
          {:ok, FxRate.t()} | {:error, Ecto.Changeset.t()}
  def upsert_rate(currency, rate, fetched_at \\ DateTime.utc_now()) do
    attrs = %{
      base: currency,
      quote: @base_currency,
      rate: to_decimal(rate),
      fetched_at: DateTime.truncate(fetched_at, :second)
    }

    case latest_rate(currency) do
      nil -> FxRate.changeset(%FxRate{}, attrs) |> Repo.insert()
      existing -> FxRate.changeset(existing, attrs) |> Repo.update()
    end
  end

  @doc """
  Pull the latest quotes for every supported currency from the live API
  and upsert them. Returns the list of successfully refreshed currencies.
  """
  @spec refresh!() :: [String.t()]
  def refresh!(currencies \\ supported_currencies()) do
    {:ok, rates} = http_client().fetch_rates(@base_currency, currencies)
    now = DateTime.utc_now()

    Enum.flat_map(rates, fn {currency, rate} ->
      case upsert_rate(currency, rate, now) do
        {:ok, _} -> [currency]
        {:error, _} -> []
      end
    end)
  end

  @doc "Currencies the system can quote against KRW (KRW excluded)."
  def supported_currencies, do: ~w(USD EUR JPY GBP)

  @doc false
  def all_rates do
    from(r in FxRate, order_by: r.base) |> Repo.all()
  end

  defp http_client do
    Application.get_env(:auto_my_invoice, __MODULE__, [])
    |> Keyword.get(:client, AutoMyInvoice.FxRates.HttpClient)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(n) when is_binary(n), do: Decimal.new(n)
end
