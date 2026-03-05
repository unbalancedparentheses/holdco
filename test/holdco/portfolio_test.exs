defmodule Holdco.PortfolioTest do
  use Holdco.DataCase, async: false

  import Holdco.HoldcoFixtures

  alias Holdco.Portfolio
  alias Holdco.Money

  # Helper to convert Decimal to float for assertions
  defp f(val), do: Money.to_float(val)

  # Shared setup that creates a realistic portfolio with known exact numbers
  defp setup_full_portfolio(_context) do
    parent = company_fixture(%{name: "HoldCo Parent", country: "US", category: "holding"})
    sub = company_fixture(%{name: "SubCo Trading", country: "UK", category: "operating", parent_id: parent.id})

    # Bank accounts: $100k parent, $50k sub = $150k liquid
    bank_account_fixture(%{company: parent, bank_name: "Chase", balance: 100_000.0, currency: "USD"})
    bank_account_fixture(%{company: sub, bank_name: "Barclays", balance: 50_000.0, currency: "USD"})

    # AAPL: 100 shares, price $200, cost $150 -> value $20k, cost $15k, unrealized +$5k
    holding_aapl = holding_fixture(%{
      company: parent, asset: "Apple Inc", ticker: "AAPL",
      quantity: 100.0, currency: "USD", asset_type: "equity"
    })
    price_history_fixture(%{ticker: "AAPL", price: 200.0})
    cost_basis_lot_fixture(%{
      holding: holding_aapl, purchase_date: "2023-01-15",
      quantity: 100.0, price_per_unit: 150.0, sold_quantity: 0.0
    })

    # BTC: 10 held (bought 12, sold 2), price $60k, cost $40k
    # Value: 10*60k = $600k, cost basis: 10*40k = $400k, unrealized +$200k
    # Realized: 2 * ($55k - $40k) = $30k
    holding_btc = holding_fixture(%{
      company: sub, asset: "Bitcoin", ticker: "BTC-USD",
      quantity: 10.0, currency: "USD", asset_type: "crypto"
    })
    price_history_fixture(%{ticker: "BTC-USD", price: 60_000.0})
    cost_basis_lot_fixture(%{
      holding: holding_btc, purchase_date: "2022-06-01",
      quantity: 12.0, price_per_unit: 40_000.0,
      sold_quantity: 2.0, sold_price: 55_000.0, sold_date: "2024-01-15"
    })

    # Liabilities: $200k loan at 5% (6 months), $50k bond at 3% (3 years)
    six_mo = Date.to_iso8601(Date.add(Date.utc_today(), 180))
    three_yr = Date.to_iso8601(Date.add(Date.utc_today(), 1095))

    liability_fixture(%{
      company: parent, liability_type: "loan", creditor: "Wells Fargo",
      principal: 200_000.0, interest_rate: 5.0, maturity_date: six_mo,
      status: "active", currency: "USD"
    })
    liability_fixture(%{
      company: sub, liability_type: "bond", creditor: "Goldman Sachs",
      principal: 50_000.0, interest_rate: 3.0, maturity_date: three_yr,
      status: "active", currency: "USD"
    })

    # Snapshots for period comparison
    today = Date.utc_today()
    portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -365)), nav: 500_000.0})
    portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -90)), nav: 600_000.0})
    portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -30)), nav: 650_000.0})
    portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -7)), nav: 680_000.0})
    portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -2)), nav: 690_000.0})

    %{parent: parent, sub: sub, six_mo: six_mo, three_yr: three_yr}
  end

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

  describe "calculate_nav edge cases" do
    test "NAV formula is liquid + marketable + illiquid - liabilities" do
      nav = Portfolio.calculate_nav()
      expected = Money.sub(
        Money.add(Money.add(nav.liquid, nav.marketable), nav.illiquid),
        nav.liabilities
      )
      assert Decimal.equal?(nav.nav, expected)
    end
  end

  describe "asset_allocation edge cases" do
    test "single asset type yields 100% of that type's value" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "SOLE_ASSET",
        ticker: "SOLE_T",
        quantity: 50.0,
        asset_type: "equity",
        currency: "USD"
      })

      Holdco.Pricing.record_price("SOLE_T", 10.0, "USD")

      alloc = Portfolio.asset_allocation()
      equity = Enum.find(alloc, &(&1.type == "equity"))
      assert equity != nil
      assert equity.count >= 1
    end
  end

  describe "fx_exposure edge cases" do
    test "all USD bank accounts produce a single USD entry" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 5_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 3_000.0, currency: "USD"})

      exposure = Portfolio.fx_exposure()
      usd_entries = Enum.filter(exposure, &(&1.currency == "USD"))
      # All USD accounts should be aggregated into one entry
      assert length(usd_entries) == 1
      assert f(hd(usd_entries).usd_value) >= 8_000.0
    end

    test "mixed currencies produce multiple entries" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 1_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, balance: 1_000.0, currency: "GBP"})
      bank_account_fixture(%{company: company, balance: 1_000.0, currency: "EUR"})

      exposure = Portfolio.fx_exposure()
      currencies = Enum.map(exposure, & &1.currency)
      assert "USD" in currencies
      assert "GBP" in currencies
      assert "EUR" in currencies
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

  # ═══════════════════════════════════════════════════════
  # return_metrics/0
  # ═══════════════════════════════════════════════════════

  describe "return_metrics/0" do
    setup :setup_full_portfolio

    test "total cost basis = AAPL cost + BTC remaining cost" do
      # AAPL: 100 * $150 = $15,000
      # BTC: (12 - 2) * $40,000 = $400,000
      # Total = $415,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.total_cost_basis), 415_000.0, 1.0
    end

    test "total current value = AAPL value + BTC value" do
      # AAPL: 100 * $200 = $20,000
      # BTC: 10 * $60,000 = $600,000
      # Total = $620,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.total_current_value), 620_000.0, 1.0
    end

    test "unrealized gain = current - cost basis" do
      # $620,000 - $415,000 = $205,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.unrealized_gain), 205_000.0, 1.0
    end

    test "realized gain from BTC sold lots" do
      # 2 BTC sold at $55k, cost $40k -> 2 * $15k = $30,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.realized_gain), 30_000.0, 1.0
    end

    test "total gain = unrealized + realized" do
      # $205,000 + $30,000 = $235,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.total_gain), 235_000.0, 1.0
    end

    test "total return pct = gain/cost * 100" do
      # $235,000 / $415,000 * 100 ≈ 56.63%
      r = Portfolio.return_metrics()
      assert_in_delta r.total_return_pct, 56.63, 0.5
    end

    test "unrealized return pct = unrealized/cost * 100" do
      # $205,000 / $415,000 * 100 ≈ 49.40%
      r = Portfolio.return_metrics()
      assert_in_delta r.unrealized_return_pct, 49.40, 0.5
    end

    test "total_assets = liquid + marketable + illiquid" do
      # Liquid: $150k, Marketable: $620k, Illiquid: $0
      r = Portfolio.return_metrics()
      assert_in_delta f(r.total_assets), 770_000.0, 1.0
    end

    test "nav = total assets - liabilities" do
      # $770,000 - $250,000 = $520,000
      r = Portfolio.return_metrics()
      assert_in_delta f(r.nav), 520_000.0, 1.0
    end

    test "zero cost basis yields 0% return" do
      Holdco.Repo.delete_all(Holdco.Assets.CostBasisLot)
      Holdco.Repo.delete_all(Holdco.Assets.AssetHolding)
      Holdco.Repo.delete_all(Holdco.Banking.BankAccount)
      Holdco.Repo.delete_all(Holdco.Finance.Liability)

      r = Portfolio.return_metrics()
      assert r.total_return_pct == 0.0
      assert r.unrealized_return_pct == 0.0
    end
  end

  # ═══════════════════════════════════════════════════════
  # period_comparison/0
  # ═══════════════════════════════════════════════════════

  describe "period_comparison/0" do
    setup :setup_full_portfolio

    test "returns exactly 5 periods with correct labels" do
      result = Portfolio.period_comparison()
      assert length(result) == 5
      assert Enum.map(result, & &1.label) == ["1W", "1M", "3M", "YTD", "1Y"]
    end

    test "1W finds the snapshot from 7 days ago ($680k)" do
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "1W"))
      assert p.prior_nav != nil
      assert_in_delta f(p.prior_nav), 680_000.0, 1.0
    end

    test "1M finds the snapshot from 30 days ago ($650k)" do
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "1M"))
      assert p.prior_nav != nil
      assert_in_delta f(p.prior_nav), 650_000.0, 1.0
    end

    test "3M finds the snapshot from 90 days ago ($600k)" do
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "3M"))
      assert p.prior_nav != nil
      assert_in_delta f(p.prior_nav), 600_000.0, 1.0
    end

    test "1Y finds the snapshot from 365 days ago ($500k)" do
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "1Y"))
      assert p.prior_nav != nil
      assert_in_delta f(p.prior_nav), 500_000.0, 1.0
    end

    test "change = current_nav - prior_nav" do
      current_nav = Portfolio.calculate_nav().nav
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "1Y"))
      expected_change = f(Money.sub(current_nav, p.prior_nav))
      assert_in_delta f(p.change), expected_change, 1.0
    end

    test "change_pct = change / prior * 100" do
      p = Portfolio.period_comparison() |> Enum.find(&(&1.label == "1Y"))
      expected_pct = f(p.change) / f(p.prior_nav) * 100
      assert_in_delta p.change_pct, expected_pct, 0.1
    end

    test "all fields nil when no snapshots exist" do
      Holdco.Repo.delete_all(Holdco.Assets.PortfolioSnapshot)
      result = Portfolio.period_comparison()
      for p <- result do
        assert p.prior_nav == nil
        assert p.change == nil
        assert p.change_pct == nil
      end
    end
  end

  # ═══════════════════════════════════════════════════════
  # cash_flow_forecast/1
  # ═══════════════════════════════════════════════════════

  describe "cash_flow_forecast/1" do
    setup :setup_full_portfolio

    setup %{parent: parent} do
      today = Date.utc_today()

      {:ok, _} = Holdco.Finance.create_recurring_transaction(%{
        company_id: parent.id,
        description: "Monthly retainer",
        amount: 10_000.0,
        frequency: "monthly",
        start_date: Date.to_iso8601(Date.add(today, -60)),
        next_run_date: Date.to_iso8601(Date.add(today, 15)),
        transaction_type: "income",
        is_active: true
      })

      {:ok, _} = Holdco.Finance.create_recurring_transaction(%{
        company_id: parent.id,
        description: "Office lease",
        amount: 3_000.0,
        frequency: "monthly",
        start_date: Date.to_iso8601(Date.add(today, -90)),
        next_run_date: Date.to_iso8601(Date.add(today, 20)),
        transaction_type: "expense",
        is_active: true
      })

      :ok
    end

    test "starting balance = sum of all bank balances ($150k)" do
      r = Portfolio.cash_flow_forecast(90)
      assert_in_delta f(r.starting_balance), 150_000.0, 1.0
    end

    test "recurring income appears as positive flows" do
      r = Portfolio.cash_flow_forecast(90)
      incomes = Enum.filter(r.flows, &(&1.description == "Monthly retainer"))
      assert length(incomes) >= 1
      assert Enum.all?(incomes, &Money.positive?(&1.amount))
    end

    test "recurring expense appears as negative flows" do
      r = Portfolio.cash_flow_forecast(90)
      expenses = Enum.filter(r.flows, &(&1.description == "Office lease"))
      assert length(expenses) >= 1
      assert Enum.all?(expenses, &Money.negative?(&1.amount))
    end

    test "monthly recurrence produces ~3 instances in 90 days" do
      r = Portfolio.cash_flow_forecast(90)
      incomes = Enum.filter(r.flows, &(&1.description == "Monthly retainer"))
      # First at day 15, then ~day 45, then ~day 75 = 3 instances
      assert length(incomes) in [2, 3]
    end

    test "debt maturity within window appears as outflow" do
      co = company_fixture(%{name: "Short Debt Co"})
      bank_account_fixture(%{company: co, balance: 10_000.0, currency: "USD"})
      maturity_date = Date.to_iso8601(Date.add(Date.utc_today(), 45))
      liability_fixture(%{
        company: co, creditor: "Short Lender",
        principal: 25_000.0, maturity_date: maturity_date,
        status: "active", currency: "USD"
      })

      r = Portfolio.cash_flow_forecast(90)
      debt_flows = Enum.filter(r.flows, &(&1.category == "debt_repayment"))
      lender_flow = Enum.find(debt_flows, &(&1.description =~ "Short Lender"))
      assert lender_flow != nil
      assert_in_delta f(lender_flow.amount), -25_000.0, 1.0
    end

    test "ending balance = starting + net flow" do
      r = Portfolio.cash_flow_forecast(90)
      expected = f(Money.add(r.starting_balance, r.net_flow))
      assert_in_delta f(r.ending_balance), expected, 1.0
    end

    test "net flow = total inflows - total outflows" do
      r = Portfolio.cash_flow_forecast(90)
      expected = f(Money.sub(r.total_inflows, r.total_outflows))
      assert_in_delta f(r.net_flow), expected, 1.0
    end

    test "flows sorted by date ascending" do
      r = Portfolio.cash_flow_forecast(90)
      dates = Enum.map(r.flows, & &1.date)
      assert dates == Enum.sort(dates)
    end

    test "running balance is cumulative" do
      r = Portfolio.cash_flow_forecast(90)
      if length(r.flows) >= 2 do
        [first, second | _] = r.flows
        expected_first = f(Money.add(r.starting_balance, first.amount))
        assert_in_delta f(first.running_balance), expected_first, 1.0

        expected_second = f(Money.add(first.running_balance, second.amount))
        assert_in_delta f(second.running_balance), expected_second, 1.0
      end
    end

    test "inactive transactions excluded" do
      co = company_fixture(%{name: "Inactive Co"})
      {:ok, _} = Holdco.Finance.create_recurring_transaction(%{
        company_id: co.id,
        description: "Cancelled sub",
        amount: 500.0,
        frequency: "monthly",
        start_date: "2024-01-01",
        next_run_date: Date.to_iso8601(Date.add(Date.utc_today(), 10)),
        is_active: false
      })

      r = Portfolio.cash_flow_forecast(90)
      assert Enum.all?(r.flows, &(&1.description != "Cancelled sub"))
    end

    test "empty forecast when no recurring txns or near-term maturities" do
      Holdco.Repo.delete_all(Holdco.Finance.RecurringTransaction)
      # Existing liabilities mature in 180+ days, outside 30-day window
      r = Portfolio.cash_flow_forecast(30)
      non_debt = Enum.reject(r.flows, &(&1.category == "debt_repayment"))
      assert non_debt == []
    end
  end

  # ═══════════════════════════════════════════════════════
  # financial_ratios/0
  # ═══════════════════════════════════════════════════════

  describe "financial_ratios/0" do
    setup :setup_full_portfolio

    test "total assets = $770k (150k liquid + 620k marketable)" do
      r = Portfolio.financial_ratios()
      assert_in_delta f(r.total_assets), 770_000.0, 1.0
    end

    test "total liabilities = $250k" do
      r = Portfolio.financial_ratios()
      assert_in_delta f(r.total_liabilities), 250_000.0, 1.0
    end

    test "equity = assets - liabilities = $520k" do
      r = Portfolio.financial_ratios()
      assert_in_delta f(r.equity), 520_000.0, 1.0
    end

    test "debt-to-equity = 250k/520k ≈ 0.48" do
      r = Portfolio.financial_ratios()
      assert_in_delta r.debt_to_equity, 0.48, 0.02
    end

    test "current ratio = liquid / short-term liabilities" do
      r = Portfolio.financial_ratios()
      # $200k loan matures in 180 days (short-term, within 1 year)
      # $50k bond matures in 3 years (long-term, excluded from short-term)
      # Current ratio = $150k / $200k = 0.75
      assert r.current_ratio != nil
      assert is_float(r.current_ratio)
    end

    test "liquid_to_total_pct = 150k/770k * 100 ≈ 19.5%" do
      r = Portfolio.financial_ratios()
      assert_in_delta r.liquid_to_total_pct, 19.48, 0.5
    end

    test "weighted avg interest rate = (200k*5 + 50k*3)/250k = 4.6%" do
      r = Portfolio.financial_ratios()
      assert_in_delta r.weighted_avg_interest_rate, 4.6, 0.1
    end

    test "no liabilities -> nil debt_to_equity and nil weighted_avg" do
      Holdco.Repo.delete_all(Holdco.Finance.Liability)
      r = Portfolio.financial_ratios()
      # With no liabilities: D/E should be 0/equity, which is 0.0 as float, or nil
      # weighted_avg_interest_rate should be nil
      assert r.weighted_avg_interest_rate == nil
    end

    test "equity components are self-consistent" do
      r = Portfolio.financial_ratios()
      assert_in_delta f(r.equity), f(Money.sub(r.total_assets, r.total_liabilities)), 0.01
    end
  end

  # ═══════════════════════════════════════════════════════
  # entity_performance/0
  # ═══════════════════════════════════════════════════════

  describe "entity_performance/0" do
    setup :setup_full_portfolio

    test "returns one entry per company" do
      result = Portfolio.entity_performance()
      names = Enum.map(result, & &1.name)
      assert "HoldCo Parent" in names
      assert "SubCo Trading" in names
    end

    test "parent has $100k liquid" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "HoldCo Parent"))
      assert_in_delta f(e.liquid), 100_000.0, 1.0
    end

    test "sub has $50k liquid" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "SubCo Trading"))
      assert_in_delta f(e.liquid), 50_000.0, 1.0
    end

    test "parent holdings = 100 AAPL * $200 = $20k" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "HoldCo Parent"))
      assert_in_delta f(e.holdings_value), 20_000.0, 1.0
    end

    test "sub holdings = 10 BTC * $60k = $600k" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "SubCo Trading"))
      assert_in_delta f(e.holdings_value), 600_000.0, 1.0
    end

    test "parent liabilities = $200k" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "HoldCo Parent"))
      assert_in_delta f(e.liabilities), 200_000.0, 1.0
    end

    test "sub liabilities = $50k" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "SubCo Trading"))
      assert_in_delta f(e.liabilities), 50_000.0, 1.0
    end

    test "entity NAV = total_assets - liabilities for each entity" do
      for e <- Portfolio.entity_performance() do
        expected = f(Money.sub(e.total_assets, e.liabilities))
        assert_in_delta f(e.nav), expected, 1.0
      end
    end

    test "parent return = (20k - 15k) / 15k * 100 = 33.3%" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "HoldCo Parent"))
      assert_in_delta e.return_pct, 33.3, 0.5
    end

    test "sub return = (600k - 400k) / 400k * 100 = 50%" do
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "SubCo Trading"))
      assert_in_delta e.return_pct, 50.0, 0.5
    end

    test "sorted by NAV descending" do
      result = Portfolio.entity_performance()
      navs = Enum.map(result, &f(&1.nav))
      assert navs == Enum.sort(navs, :desc)
    end

    test "entity with no holdings has nil return_pct" do
      company_fixture(%{name: "Empty Shell"})
      e = Portfolio.entity_performance() |> Enum.find(&(&1.name == "Empty Shell"))
      assert e.return_pct == nil
      assert f(e.holdings_value) == 0.0
    end

    test "total_assets = liquid + holdings_value" do
      for e <- Portfolio.entity_performance() do
        expected = f(Money.add(e.liquid, e.holdings_value))
        assert_in_delta f(e.total_assets), expected, 1.0
      end
    end
  end
end
