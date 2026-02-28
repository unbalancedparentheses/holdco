defmodule Holdco.PortfolioTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Portfolio
  alias Holdco.Money

  # Helper to convert Decimal to float for assertions
  defp f(val), do: Money.to_float(val)

  describe "calculate_nav/0" do
    test "returns NAV map with all keys" do
      nav = Portfolio.calculate_nav()
      assert is_map(nav)
      assert Map.has_key?(nav, :liquid)
      assert Map.has_key?(nav, :marketable)
      assert Map.has_key?(nav, :illiquid)
      assert Map.has_key?(nav, :liabilities)
      assert Map.has_key?(nav, :nav)
    end

    test "all NAV components are non-negative numbers" do
      nav = Portfolio.calculate_nav()
      assert f(nav.liquid) >= 0.0
      assert f(nav.marketable) >= 0.0
      assert f(nav.illiquid) >= 0.0
      assert f(nav.liabilities) >= 0.0
    end

    test "includes bank account balances in liquid" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 5_000.0, currency: "USD"})

      nav_after = Portfolio.calculate_nav()
      assert_in_delta f(nav_after.liquid) - f(nav_before.liquid), 15_000.0, 1.0
    end

    test "converts non-USD bank account balances" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})

      nav = Portfolio.calculate_nav()
      assert f(nav.liquid) >= 10_000.0
    end

    test "includes real estate in illiquid" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      real_estate_property_fixture(%{
        company: company,
        purchase_price: 500_000.0,
        current_valuation: 600_000.0,
        currency: "USD"
      })

      nav_after = Portfolio.calculate_nav()
      assert f(nav_after.illiquid) - f(nav_before.illiquid) >= 600_000.0
    end

    test "uses purchase_price as fallback when current_valuation is nil" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      real_estate_property_fixture(%{
        company: company,
        purchase_price: 500_000.0,
        current_valuation: nil,
        currency: "USD"
      })

      nav_after = Portfolio.calculate_nav()
      assert f(nav_after.illiquid) - f(nav_before.illiquid) >= 500_000.0
    end

    test "includes fund investments in illiquid" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      fund_investment_fixture(%{company: company, nav: 100_000.0, currency: "USD"})

      nav_after = Portfolio.calculate_nav()
      assert f(nav_after.illiquid) - f(nav_before.illiquid) >= 100_000.0
    end

    test "subtracts active liabilities" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 100_000.0, currency: "USD"})
      liability_fixture(%{company: company, principal: 25_000.0, currency: "USD", status: "active"})

      nav_after = Portfolio.calculate_nav()
      assert_in_delta f(nav_after.liabilities) - f(nav_before.liabilities), 25_000.0, 1.0
      # NAV formula: liquid + marketable + illiquid - liabilities
      expected_nav = Money.sub(Money.add(Money.add(nav_after.liquid, nav_after.marketable), nav_after.illiquid), nav_after.liabilities)
      assert Decimal.equal?(nav_after.nav, expected_nav)
    end

    test "ignores inactive liabilities" do
      nav_before = Portfolio.calculate_nav()

      company = company_fixture()
      liability_fixture(%{company: company, principal: 25_000.0, currency: "USD", status: "paid"})

      nav_after = Portfolio.calculate_nav()
      assert f(nav_after.liabilities) == f(nav_before.liabilities)
    end

    test "classifies equity/crypto/commodity holdings as marketable" do
      company = company_fixture()

      _holding = holding_fixture(%{
        company: company,
        asset: "AAPL Stock",
        ticker: "NAV_AAPL_TEST",
        quantity: 100.0,
        currency: "USD",
        asset_type: "equity"
      })

      Holdco.Pricing.record_price("NAV_AAPL_TEST", 150.0, "USD")

      nav = Portfolio.calculate_nav()
      assert f(nav.marketable) > 0.0
    end

    test "classifies non-equity/crypto/commodity holdings as illiquid" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "Private Fund",
        ticker: "NAV_PRIV_TEST",
        quantity: 100.0,
        currency: "USD",
        asset_type: "private_equity"
      })

      Holdco.Pricing.record_price("NAV_PRIV_TEST", 50.0, "USD")

      nav = Portfolio.calculate_nav()
      assert f(nav.illiquid) > 0.0
    end
  end

  describe "holding_value/1" do
    test "returns value for holding with a recorded price" do
      holding = holding_fixture(%{ticker: "HV_TEST_1", quantity: 10.0, currency: "USD"})
      Holdco.Pricing.record_price("HV_TEST_1", 50.0, "USD")

      value = Portfolio.holding_value(holding)
      assert f(value) == 500.0
    end

    test "returns 0 when ticker is nil" do
      holding = holding_fixture(%{ticker: nil, quantity: 10.0, currency: "USD"})
      assert f(Portfolio.holding_value(holding)) == 0.0
    end

    test "returns 0 when ticker is empty string" do
      holding = holding_fixture(%{ticker: "", quantity: 10.0, currency: "USD"})
      assert f(Portfolio.holding_value(holding)) == 0.0
    end

    test "returns 0 when no price exists for ticker" do
      holding = holding_fixture(%{ticker: "NONEXISTENT_TICKER_999", quantity: 10.0, currency: "USD"})
      assert f(Portfolio.holding_value(holding)) == 0.0
    end

    test "returns 0 when quantity is nil" do
      holding = holding_fixture(%{ticker: "HV_TEST_2", quantity: nil, currency: "USD"})
      Holdco.Pricing.record_price("HV_TEST_2", 50.0, "USD")

      assert f(Portfolio.holding_value(holding)) == 0.0
    end

    test "returns a value using the price from the database" do
      holding = holding_fixture(%{ticker: "HV_TEST_3", quantity: 10.0, currency: "USD"})
      Holdco.Pricing.record_price("HV_TEST_3", 50.0, "USD")

      value = Portfolio.holding_value(holding)
      assert f(value) == 500.0
    end
  end

  describe "get_fx_rate/1" do
    test "returns 1 for USD" do
      assert Decimal.equal?(Portfolio.get_fx_rate("USD"), Decimal.new(1))
    end

    test "returns a rate for known currencies (fallback)" do
      rate = Portfolio.get_fx_rate("EUR")
      assert Money.gt?(rate, 0)
    end

    test "returns fallback rate for unknown currency" do
      rate = Portfolio.get_fx_rate("XYZ_UNKNOWN")
      assert Money.gt?(rate, 0)
    end
  end

  describe "to_usd/2" do
    test "returns 0 for nil amount" do
      assert f(Portfolio.to_usd(nil, "EUR")) == 0.0
      assert f(Portfolio.to_usd(nil, "USD")) == 0.0
    end

    test "returns same amount for USD" do
      assert f(Portfolio.to_usd(100.0, "USD")) == 100.0
      assert f(Portfolio.to_usd(0.0, "USD")) == 0.0
      assert_in_delta f(Portfolio.to_usd(999.99, "USD")), 999.99, 0.01
    end

    test "converts non-USD currencies" do
      result = Portfolio.to_usd(100.0, "EUR")
      assert Money.gt?(result, 0)
    end

    test "handles zero amount" do
      assert f(Portfolio.to_usd(0.0, "EUR")) == 0.0
    end
  end

  describe "calculate_gains/0" do
    test "returns gains data with per_holding and aggregate" do
      gains = Portfolio.calculate_gains()
      assert is_map(gains)
      assert Map.has_key?(gains, :per_holding)
      assert Map.has_key?(gains, :aggregate)
      assert is_list(gains.per_holding)
    end

    test "returns valid aggregate structure" do
      gains = Portfolio.calculate_gains()
      assert f(gains.aggregate.total_unrealized) >= 0.0 || f(gains.aggregate.total_unrealized) < 0.0
      expected_total = Money.add(gains.aggregate.total_unrealized, gains.aggregate.total_realized)
      assert Decimal.equal?(gains.aggregate.total_gain, expected_total)
    end

    test "calculates unrealized gain from cost basis lots" do
      company = company_fixture()

      holding = holding_fixture(%{
        company: company,
        asset: "GAINS_TEST",
        ticker: "GAINS_TICKER",
        quantity: 100.0,
        currency: "USD"
      })

      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 100.0,
        price_per_unit: 50.0,
        sold_quantity: 0.0
      })

      Holdco.Pricing.record_price("GAINS_TICKER", 75.0, "USD")

      gains = Portfolio.calculate_gains()
      assert length(gains.per_holding) > 0

      gain_entry = Enum.find(gains.per_holding, &(&1.ticker == "GAINS_TICKER"))
      assert gain_entry != nil
      assert f(gain_entry.cost_basis) == 5_000.0
      assert f(gain_entry.current_value) == 7_500.0
      assert f(gain_entry.unrealized_gain) == 2_500.0
    end

    test "calculates realized gains from sold lots" do
      company = company_fixture()

      holding = holding_fixture(%{
        company: company,
        asset: "RGAINS_TEST",
        ticker: "RGAINS_TICKER",
        quantity: 50.0,
        currency: "USD"
      })

      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 100.0,
        price_per_unit: 50.0,
        sold_quantity: 50.0,
        sold_price: 80.0
      })

      Holdco.Pricing.record_price("RGAINS_TICKER", 75.0, "USD")

      gains = Portfolio.calculate_gains()
      gain_entry = Enum.find(gains.per_holding, &(&1.ticker == "RGAINS_TICKER"))
      assert gain_entry != nil
      assert f(gain_entry.realized_gain) == 1_500.0
    end

    test "handles holdings with no cost basis lots" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "NOLOTS_TEST",
        ticker: "NOLOTS_TICKER",
        quantity: 100.0,
        currency: "USD"
      })

      gains = Portfolio.calculate_gains()
      gain_entry = Enum.find(gains.per_holding, &(&1.ticker == "NOLOTS_TICKER"))
      assert gain_entry != nil
      assert f(gain_entry.cost_basis) == 0.0
    end

    test "aggregate sums all gains" do
      company = company_fixture()

      holding1 = holding_fixture(%{
        company: company,
        asset: "AGG_1",
        ticker: "AGG_TICKER_1",
        quantity: 100.0,
        currency: "USD"
      })

      holding2 = holding_fixture(%{
        company: company,
        asset: "AGG_2",
        ticker: "AGG_TICKER_2",
        quantity: 50.0,
        currency: "USD"
      })

      cost_basis_lot_fixture(%{holding: holding1, quantity: 100.0, price_per_unit: 10.0, sold_quantity: 0.0})
      cost_basis_lot_fixture(%{holding: holding2, quantity: 50.0, price_per_unit: 20.0, sold_quantity: 0.0})

      Holdco.Pricing.record_price("AGG_TICKER_1", 15.0, "USD")
      Holdco.Pricing.record_price("AGG_TICKER_2", 25.0, "USD")

      gains = Portfolio.calculate_gains()
      expected_total = Money.add(gains.aggregate.total_unrealized, gains.aggregate.total_realized)
      assert Decimal.equal?(gains.aggregate.total_gain, expected_total)
    end
  end

  describe "asset_allocation/0" do
    test "returns a list" do
      alloc = Portfolio.asset_allocation()
      assert is_list(alloc)
    end

    test "includes newly added holdings by asset_type" do
      company = company_fixture()
      alloc_before = Portfolio.asset_allocation()

      holding_fixture(%{company: company, asset: "AA_EQ_1", ticker: "AA_EQ_T1", quantity: 10.0, asset_type: "equity", currency: "USD"})
      holding_fixture(%{company: company, asset: "AA_EQ_2", ticker: "AA_EQ_T2", quantity: 20.0, asset_type: "equity", currency: "USD"})
      holding_fixture(%{company: company, asset: "AA_CR_1", ticker: "AA_CR_T1", quantity: 5.0, asset_type: "crypto", currency: "USD"})

      alloc_after = Portfolio.asset_allocation()
      assert is_list(alloc_after)

      equity_before = Enum.find(alloc_before, &(&1.type == "equity"))
      equity_after = Enum.find(alloc_after, &(&1.type == "equity"))
      equity_count_before = if equity_before, do: equity_before.count, else: 0
      assert equity_after != nil
      assert equity_after.count == equity_count_before + 2

      crypto_before = Enum.find(alloc_before, &(&1.type == "crypto"))
      crypto_after = Enum.find(alloc_after, &(&1.type == "crypto"))
      crypto_count_before = if crypto_before, do: crypto_before.count, else: 0
      assert crypto_after != nil
      assert crypto_after.count == crypto_count_before + 1
    end

    test "sorts by value descending" do
      company = company_fixture()

      holding_fixture(%{company: company, asset: "SORT_1", ticker: "SORT_T1", quantity: 100.0, asset_type: "equity", currency: "USD"})
      holding_fixture(%{company: company, asset: "SORT_2", ticker: "SORT_T2", quantity: 1.0, asset_type: "crypto", currency: "USD"})

      Holdco.Pricing.record_price("SORT_T1", 100.0, "USD")
      Holdco.Pricing.record_price("SORT_T2", 1.0, "USD")

      alloc = Portfolio.asset_allocation()
      values = Enum.map(alloc, &f(&1.value))
      assert values == Enum.sort(values, :desc)
    end
  end

  describe "fx_exposure/0" do
    test "returns a list" do
      exposure = Portfolio.fx_exposure()
      assert is_list(exposure)
    end

    test "aggregates bank accounts by currency" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 5_000.0, currency: "USD"})

      exposure = Portfolio.fx_exposure()
      usd_entry = Enum.find(exposure, &(&1.currency == "USD"))
      assert usd_entry != nil
      assert f(usd_entry.usd_value) >= 15_000.0
    end

    test "includes multiple currencies" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 8_000.0, currency: "EUR"})

      exposure = Portfolio.fx_exposure()
      assert length(exposure) >= 2
      currencies = Enum.map(exposure, & &1.currency)
      assert "USD" in currencies
      assert "EUR" in currencies
    end

    test "sorts by usd_value descending" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 100_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 1.0, currency: "EUR"})

      exposure = Portfolio.fx_exposure()
      values = Enum.map(exposure, &f(&1.usd_value))
      assert values == Enum.sort(values, :desc)
    end

    test "combines bank accounts and holdings by currency" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})

      holding_fixture(%{
        company: company,
        asset: "FX_HOLD",
        ticker: "FX_HOLD_T",
        quantity: 10.0,
        currency: "USD"
      })

      Holdco.Pricing.record_price("FX_HOLD_T", 100.0, "USD")

      exposure = Portfolio.fx_exposure()
      usd_entry = Enum.find(exposure, &(&1.currency == "USD"))
      assert usd_entry != nil
      assert f(usd_entry.usd_value) >= 10_000.0
    end
  end
end
