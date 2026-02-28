defmodule Holdco.Analytics.LiquidityCoverageTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  # ── CRUD Tests ──────────────────────────────────────────────

  describe "CRUD" do
    test "create_liquidity_coverage/1 with valid attrs" do
      company = company_fixture()

      assert {:ok, lc} =
               Analytics.create_liquidity_coverage(%{
                 company_id: company.id,
                 calculation_date: ~D[2026-02-28],
                 hqla_level1: 1_000_000.0,
                 hqla_level2a: 200_000.0,
                 hqla_level2b: 50_000.0,
                 total_hqla: 1_250_000.0,
                 net_cash_outflows_30d: 800_000.0,
                 lcr_ratio: 156.25,
                 status: "adequate"
               })

      assert lc.status == "adequate"
      assert lc.calculation_date == ~D[2026-02-28]
    end

    test "create_liquidity_coverage/1 fails without calculation_date" do
      assert {:error, changeset} =
               Analytics.create_liquidity_coverage(%{
                 hqla_level1: 100.0
               })

      assert %{calculation_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_liquidity_coverage/1 validates status inclusion" do
      assert {:error, changeset} =
               Analytics.create_liquidity_coverage(%{
                 calculation_date: ~D[2026-01-01],
                 status: "invalid"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "list_liquidity_coverages/0 returns all records" do
      lc = liquidity_coverage_fixture()
      coverages = Analytics.list_liquidity_coverages()
      assert length(coverages) >= 1
      assert Enum.any?(coverages, &(&1.id == lc.id))
    end

    test "list_liquidity_coverages/1 filters by company_id" do
      c1 = company_fixture(%{name: "LiqCo1"})
      c2 = company_fixture(%{name: "LiqCo2"})
      lc1 = liquidity_coverage_fixture(%{company_id: c1.id})
      _lc2 = liquidity_coverage_fixture(%{company_id: c2.id})

      coverages = Analytics.list_liquidity_coverages(c1.id)
      assert length(coverages) == 1
      assert hd(coverages).id == lc1.id
    end

    test "get_liquidity_coverage!/1 returns the record" do
      lc = liquidity_coverage_fixture()
      found = Analytics.get_liquidity_coverage!(lc.id)
      assert found.id == lc.id
    end

    test "get_liquidity_coverage!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_liquidity_coverage!(0)
      end
    end

    test "update_liquidity_coverage/2 updates successfully" do
      lc = liquidity_coverage_fixture()

      assert {:ok, updated} =
               Analytics.update_liquidity_coverage(lc, %{status: "warning", notes: "Updated"})

      assert updated.status == "warning"
      assert updated.notes == "Updated"
    end

    test "delete_liquidity_coverage/1 deletes the record" do
      lc = liquidity_coverage_fixture()
      assert {:ok, _} = Analytics.delete_liquidity_coverage(lc)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_liquidity_coverage!(lc.id)
      end
    end
  end

  # ── calculate_lcr Tests ─────────────────────────────────────

  describe "calculate_lcr/1" do
    test "with adequate ratio (>= 100%)" do
      company = company_fixture()

      # Create a large cash balance (Level 1 HQLA)
      bank_account_fixture(%{company: company, balance: 500_000.0, currency: "USD"})

      # Create a small liability
      liability_fixture(%{
        company: company,
        principal: 100_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      assert lc.status == "adequate"
      # HQLA = 500k, outflows = 25% of 100k = 25k, LCR = 500k/25k*100 = 2000%
      assert Decimal.compare(lc.lcr_ratio, Decimal.new(100)) in [:gt, :eq]
    end

    test "with warning ratio (80-100%)" do
      company = company_fixture()

      # Balance that will yield 80-100% LCR
      # If liability = 1_000_000, outflows = 250_000
      # For LCR 90%: HQLA needs to be 225_000
      bank_account_fixture(%{company: company, balance: 225_000.0, currency: "USD"})

      liability_fixture(%{
        company: company,
        principal: 1_000_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Big Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      assert lc.status == "warning"
      assert Decimal.compare(lc.lcr_ratio, Decimal.new(80)) in [:gt, :eq]
      assert Decimal.compare(lc.lcr_ratio, Decimal.new(100)) == :lt
    end

    test "with critical ratio (< 80%)" do
      company = company_fixture()

      # Small balance relative to liabilities
      bank_account_fixture(%{company: company, balance: 10_000.0, currency: "USD"})

      liability_fixture(%{
        company: company,
        principal: 1_000_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Mega Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      assert lc.status == "critical"
      assert Decimal.compare(lc.lcr_ratio, Decimal.new(80)) == :lt
    end

    test "with no bank accounts" do
      company = company_fixture()

      # Only liabilities, no cash
      liability_fixture(%{
        company: company,
        principal: 100_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      # Zero HQLA = critical
      assert lc.status == "critical"
      assert Decimal.equal?(lc.hqla_level1, Decimal.new(0))
    end

    test "with no liabilities returns adequate with high ratio" do
      company = company_fixture()

      bank_account_fixture(%{company: company, balance: 500_000.0, currency: "USD"})
      # No liabilities means zero outflows, which gives 999 ratio

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      assert lc.status == "adequate"
      # With no outflows, LCR defaults to 999
      assert Decimal.compare(lc.lcr_ratio, Decimal.new(100)) in [:gt, :eq]
    end

    test "lcr_ratio calculation accuracy" do
      company = company_fixture()

      # 400k cash
      bank_account_fixture(%{company: company, balance: 400_000.0, currency: "USD"})

      # 800k in liabilities -> 200k outflows
      liability_fixture(%{
        company: company,
        principal: 800_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Test Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      # LCR = 400_000 / (800_000 * 0.25) * 100 = 400_000 / 200_000 * 100 = 200%
      assert Decimal.equal?(Decimal.round(lc.lcr_ratio, 0), Decimal.new(200))
    end

    test "includes Level 2A holdings with haircut" do
      company = company_fixture()

      # Cash (Level 1)
      bank_account_fixture(%{company: company, balance: 100_000.0, currency: "USD"})

      # Government bonds (Level 2A) -- needs a price to have value
      holding_fixture(%{
        company: company,
        asset: "US Treasury",
        ticker: "GOVT",
        quantity: 100.0,
        currency: "USD",
        asset_type: "fixed_income"
      })

      price_history_fixture(%{ticker: "GOVT", price: 1000.0})

      liability_fixture(%{
        company: company,
        principal: 500_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      # Level 2A should have a value (100 * 1000 * 0.85 = 85_000)
      assert Decimal.compare(lc.hqla_level2a, Decimal.new(0)) == :gt
    end

    test "includes Level 2B holdings with haircut" do
      company = company_fixture()

      bank_account_fixture(%{company: company, balance: 50_000.0, currency: "USD"})

      # Corporate bonds (Level 2B)
      holding_fixture(%{
        company: company,
        asset: "Corporate Bond",
        ticker: "CORP",
        quantity: 200.0,
        currency: "USD",
        asset_type: "corporate_bond"
      })

      price_history_fixture(%{ticker: "CORP", price: 500.0})

      liability_fixture(%{
        company: company,
        principal: 200_000.0,
        currency: "USD",
        liability_type: "loan",
        creditor: "Bank"
      })

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      # Level 2B should have a value (200 * 500 * 0.50 = 50_000)
      assert Decimal.compare(lc.hqla_level2b, Decimal.new(0)) == :gt
    end

    test "creates a record with calculation_date set to today" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 100_000.0, currency: "USD"})

      assert {:ok, lc} = Analytics.calculate_lcr(company.id)
      assert lc.calculation_date == Date.utc_today()
    end
  end
end
