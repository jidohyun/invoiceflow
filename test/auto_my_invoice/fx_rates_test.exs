defmodule AutoMyInvoice.FxRatesTest do
  use AutoMyInvoice.DataCase, async: true

  alias AutoMyInvoice.FxRates
  alias AutoMyInvoice.FxRatesStub

  describe "to_krw/2" do
    test "returns the amount unchanged for KRW" do
      assert {:ok, krw} = FxRates.to_krw(Decimal.new("12000"), "KRW")
      assert Decimal.eq?(krw, Decimal.new("12000.00"))
    end

    test "returns :missing_rate when no cached rate exists" do
      assert {:error, :missing_rate} = FxRates.to_krw(Decimal.new(100), "USD")
    end

    test "converts USD to KRW using the cached rate" do
      FxRates.upsert_rate("USD", Decimal.new("1350"))

      assert {:ok, krw} = FxRates.to_krw(Decimal.new(100), "USD")
      assert Decimal.eq?(krw, Decimal.new("135000.00"))
    end

    test "rounds to 2 decimal places (no half-won)" do
      FxRates.upsert_rate("JPY", Decimal.new("9.123"))

      assert {:ok, krw} = FxRates.to_krw(Decimal.new(1), "JPY")
      assert Decimal.eq?(krw, Decimal.new("9.12"))
    end
  end

  describe "upsert_rate/3" do
    test "inserts a new rate" do
      assert {:ok, fx} = FxRates.upsert_rate("EUR", Decimal.new("1480"))
      assert fx.base == "EUR"
      assert fx.quote == "KRW"
    end

    test "updates an existing rate in place (no duplicate row)" do
      {:ok, _} = FxRates.upsert_rate("GBP", Decimal.new("1700"))
      {:ok, _} = FxRates.upsert_rate("GBP", Decimal.new("1725"))

      assert length(FxRates.all_rates()) == 1
      assert Decimal.eq?(FxRates.latest_rate("GBP").rate, Decimal.new("1725"))
    end
  end

  describe "refresh!/0" do
    test "pulls every supported currency from the stub client and caches it" do
      refreshed = FxRates.refresh!()

      assert "USD" in refreshed
      assert "EUR" in refreshed
      assert "JPY" in refreshed
      assert "GBP" in refreshed

      # The stub rates land in fx_rates verbatim.
      Enum.each(FxRatesStub.stub_rates(), fn {currency, rate} ->
        assert Decimal.eq?(FxRates.latest_rate(currency).rate, rate)
      end)
    end
  end
end
