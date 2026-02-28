defmodule Holdco.Integration.FundLifecycleTest do
  @moduledoc """
  Integration tests for the complete fund lifecycle:
  company creation -> capital calls -> distributions -> NAV calculation ->
  investor statements -> K-1 generation -> fee calculations -> dividend policies.
  """
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund
  alias Holdco.Finance
  alias Holdco.Corporate
  alias Holdco.Assets
  alias Holdco.Banking

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_fund_company do
    company = company_fixture(%{name: "Acme PE Fund I", country: "US"})
    company
  end

  defp create_investor_contributions(company, investor_name, amount, date) do
    {:ok, cc} =
      Finance.create_capital_contribution(%{
        company_id: company.id,
        contributor: investor_name,
        amount: amount,
        date: date
      })

    cc
  end

  defp create_investor_dividend(company, amount, date) do
    {:ok, d} =
      Finance.create_dividend(%{
        company_id: company.id,
        amount: amount,
        date: date
      })

    d
  end

  # ===========================================================================
  # 1. Full Capital Call Lifecycle
  # ===========================================================================

  describe "capital call lifecycle" do
    test "create capital call, add investor lines, mark paid, and verify call is funded" do
      company = setup_fund_company()

      {:ok, cc} =
        Fund.create_capital_call(%{
          company_id: company.id,
          call_date: "2025-01-15",
          due_date: "2025-02-15",
          total_amount: 1_000_000.0,
          purpose: "investment",
          status: "pending"
        })

      assert cc.status == "pending"

      # Add two investors
      {:ok, line_a} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "LP Alpha",
          commitment_amount: 600_000.0,
          call_amount: 600_000.0
        })

      {:ok, line_b} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "LP Beta",
          commitment_amount: 400_000.0,
          call_amount: 400_000.0
        })

      assert line_a.status == "pending"
      assert line_b.status == "pending"

      # LP Alpha pays
      {:ok, paid_a} = Fund.mark_line_paid(line_a, Decimal.new("600000"))
      assert paid_a.status == "paid"

      # After first pay, call should still be partially funded
      partial_call = Fund.get_capital_call!(cc.id)
      assert partial_call.status == "partially_funded"

      # LP Beta pays
      {:ok, paid_b} = Fund.mark_line_paid(line_b, Decimal.new("400000"))
      assert paid_b.status == "paid"

      # Now call should be fully funded
      funded_call = Fund.get_capital_call!(cc.id)
      assert funded_call.status == "funded"
    end

    test "capital call lines track partial payments" do
      company = setup_fund_company()

      {:ok, cc} =
        Fund.create_capital_call(%{
          company_id: company.id,
          call_date: "2025-03-01",
          total_amount: 500_000.0,
          purpose: "follow_on"
        })

      {:ok, line} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "LP Gamma",
          call_amount: 500_000.0
        })

      {:ok, paid} = Fund.mark_line_paid(line, Decimal.new("500000"))
      assert Decimal.equal?(paid.paid_amount, Decimal.new("500000"))
      assert paid.paid_date == Date.utc_today()
    end

    test "multiple capital calls for same company are tracked independently" do
      company = setup_fund_company()

      {:ok, cc1} =
        Fund.create_capital_call(%{
          company_id: company.id,
          call_date: "2025-01-01",
          total_amount: 200_000.0,
          purpose: "investment"
        })

      {:ok, cc2} =
        Fund.create_capital_call(%{
          company_id: company.id,
          call_date: "2025-06-01",
          total_amount: 300_000.0,
          purpose: "fees"
        })

      calls = Fund.list_capital_calls(company.id)
      assert length(calls) == 2
      ids = Enum.map(calls, & &1.id)
      assert cc1.id in ids
      assert cc2.id in ids
    end
  end

  # ===========================================================================
  # 2. Distribution Lifecycle
  # ===========================================================================

  describe "distribution lifecycle" do
    test "create distribution and auto-calculate lines for multiple investors" do
      company = setup_fund_company()

      {:ok, dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-12-15",
          total_amount: 1_000_000.0,
          distribution_type: "profit",
          status: "approved"
        })

      investors = [
        %{investor_name: "LP Alpha", ownership_pct: 60, withholding_tax_rate: 0},
        %{investor_name: "LP Beta", ownership_pct: 40, withholding_tax_rate: Decimal.new("0.15")}
      ]

      results = Fund.calculate_distribution_lines(dist.id, investors)
      assert length(results) == 2

      {:ok, line_a} = Enum.at(results, 0)
      {:ok, line_b} = Enum.at(results, 1)

      # LP Alpha: 60% of 1M = 600K, no withholding
      assert Decimal.equal?(line_a.gross_amount, Decimal.new("600000.0"))
      assert Decimal.equal?(line_a.withholding_tax, Decimal.new("0.0"))
      assert Decimal.equal?(line_a.net_amount, Decimal.new("600000.0"))

      # LP Beta: 40% of 1M = 400K, 15% withholding = 60K, net = 340K
      assert Decimal.equal?(line_b.gross_amount, Decimal.new("400000.0"))
      assert Decimal.equal?(line_b.withholding_tax, Decimal.new("60000.0"))
      assert Decimal.equal?(line_b.net_amount, Decimal.new("340000.0"))
    end

    test "distribution status transitions through pending -> approved -> distributed" do
      company = setup_fund_company()

      {:ok, dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-09-30",
          total_amount: 250_000.0,
          distribution_type: "dividend",
          status: "pending"
        })

      assert dist.status == "pending"

      {:ok, approved} = Fund.update_distribution(dist, %{status: "approved"})
      assert approved.status == "approved"

      {:ok, distributed} = Fund.update_distribution(approved, %{status: "distributed"})
      assert distributed.status == "distributed"
    end

    test "multiple distribution types are supported" do
      company = setup_fund_company()

      for dtype <- ~w(return_of_capital profit dividend liquidation) do
        {:ok, dist} =
          Fund.create_distribution(%{
            company_id: company.id,
            distribution_date: "2025-06-15",
            total_amount: 100_000.0,
            distribution_type: dtype
          })

        assert dist.distribution_type == dtype
      end
    end
  end

  # ===========================================================================
  # 3. Waterfall Calculation
  # ===========================================================================

  describe "waterfall calculation" do
    test "full waterfall: return of capital -> preferred return -> catch-up -> residual" do
      company = setup_fund_company()

      # Create tiered waterfall structure
      {:ok, t1} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 1,
          name: "Return of Capital",
          tier_type: "return_of_capital"
        })

      {:ok, t2} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 2,
          name: "8% Preferred Return",
          tier_type: "preferred_return",
          hurdle_rate: "0.08"
        })

      {:ok, t3} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 3,
          name: "GP Catch-up",
          tier_type: "catch_up",
          split_gp_pct: 100,
          split_lp_pct: 0
        })

      {:ok, t4} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 4,
          name: "Residual Split",
          tier_type: "residual",
          split_lp_pct: 80,
          split_gp_pct: 20
        })

      tiers = Fund.list_waterfall_tiers(company.id)
      assert length(tiers) == 4

      # Distribute $2M on $1M invested
      allocations = Fund.calculate_waterfall(2_000_000, 1_000_000, tiers)
      assert length(allocations) == 4

      # Tier 1: Return of Capital - LP gets back $1M
      roc = Enum.at(allocations, 0)
      assert roc.tier_type == "return_of_capital"
      assert Decimal.equal?(roc.lp_amount, Decimal.new("1000000"))
      assert Decimal.equal?(roc.gp_amount, Decimal.new("0"))

      # Tier 2: Preferred Return - LP gets 8% of $1M = $80K
      pref = Enum.at(allocations, 1)
      assert pref.tier_type == "preferred_return"
      assert Decimal.equal?(pref.lp_amount, Decimal.new("80000"))

      # Total allocated so far: $1,080,000 -> remaining: $920,000
      # Tier 3: GP catches up
      catch_up = Enum.at(allocations, 2)
      assert catch_up.tier_type == "catch_up"
      assert Decimal.gt?(catch_up.gp_amount, Decimal.new("0"))

      # Tier 4: Residual
      residual = Enum.at(allocations, 3)
      assert residual.tier_type == "residual"
    end

    test "waterfall with zero distributable returns all zeros" do
      company = setup_fund_company()

      {:ok, _} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 1,
          name: "Return of Capital",
          tier_type: "return_of_capital"
        })

      tiers = Fund.list_waterfall_tiers(company.id)
      allocations = Fund.calculate_waterfall(0, 1_000_000, tiers)

      assert Enum.all?(allocations, fn a ->
        Decimal.equal?(a.total_allocated, Decimal.new("0"))
      end)
    end
  end

  # ===========================================================================
  # 4. NAV Calculation
  # ===========================================================================

  describe "NAV calculation" do
    test "calculate_fund_nav aggregates holdings, bank balances, and liabilities" do
      company = setup_fund_company()

      # Create holdings with cost basis lots
      {:ok, holding} =
        Assets.create_holding(%{company_id: company.id, asset: "AAPL"})

      {:ok, _lot} =
        Assets.create_cost_basis_lot(%{
          holding_id: holding.id,
          purchase_date: "2025-01-01",
          quantity: 100.0,
          price_per_unit: 200.0
        })

      # Create bank account with balance
      {:ok, _ba} =
        Banking.create_bank_account(%{
          company_id: company.id,
          bank_name: "Chase",
          balance: 50_000.0
        })

      # Create a liability
      {:ok, _liability} =
        Finance.create_liability(%{
          company_id: company.id,
          liability_type: "loan",
          creditor: "Big Bank",
          principal: 10_000.0,
          status: "active"
        })

      nav_data = Fund.calculate_fund_nav(company.id)

      # Holdings: 100 * 200 = 20,000; Bank: 50,000; Total assets: 70,000
      assert Decimal.equal?(nav_data.total_assets, Decimal.new("70000"))
      assert Decimal.equal?(nav_data.total_liabilities, Decimal.new("10000"))
      assert Decimal.equal?(nav_data.net_asset_value, Decimal.new("60000"))
    end

    test "NAV record creation and retrieval" do
      company = setup_fund_company()

      {:ok, nav} =
        Fund.create_fund_nav(%{
          company_id: company.id,
          nav_date: "2025-03-31",
          total_assets: 10_000_000.0,
          total_liabilities: 2_000_000.0,
          net_asset_value: 8_000_000.0,
          nav_per_unit: 100.0,
          units_outstanding: 80_000.0
        })

      fetched = Fund.get_fund_nav!(nav.id)
      assert fetched.company != nil
      assert Decimal.equal?(fetched.net_asset_value, Decimal.from_float(8_000_000.0))
    end

    test "NAV changes after new capital call funding" do
      company = setup_fund_company()

      # Initial state: just a bank balance
      {:ok, _ba} =
        Banking.create_bank_account(%{
          company_id: company.id,
          bank_name: "Fund Account",
          balance: 100_000.0
        })

      nav_before = Fund.calculate_fund_nav(company.id)
      assert Decimal.equal?(nav_before.net_asset_value, Decimal.new("100000"))

      # Add more assets (simulate investment purchased after capital call)
      {:ok, holding} = Assets.create_holding(%{company_id: company.id, asset: "MSFT"})

      {:ok, _lot} =
        Assets.create_cost_basis_lot(%{
          holding_id: holding.id,
          purchase_date: "2025-03-01",
          quantity: 50.0,
          price_per_unit: 400.0
        })

      nav_after = Fund.calculate_fund_nav(company.id)
      # 100K bank + 50*400 = 120K
      assert Decimal.equal?(nav_after.net_asset_value, Decimal.new("120000"))
      assert Decimal.gt?(nav_after.net_asset_value, nav_before.net_asset_value)
    end
  end

  # ===========================================================================
  # 5. Investor Statement Generation
  # ===========================================================================

  describe "investor statement generation" do
    test "generate statement reflecting contributions and distributions within period" do
      company = setup_fund_company()

      # Pre-period contribution
      create_investor_contributions(company, "LP Alpha", 100_000.0, "2024-06-01")
      # In-period contribution
      create_investor_contributions(company, "LP Alpha", 50_000.0, "2025-03-15")
      # In-period distribution (dividend)
      create_investor_dividend(company, 10_000.0, "2025-06-15")

      statement =
        Fund.generate_investor_statement(
          company.id,
          "LP Alpha",
          ~D[2025-01-01],
          ~D[2025-12-31]
        )

      assert statement.investor_name == "LP Alpha"
      assert Decimal.equal?(statement.beginning_balance, Decimal.new("100000"))
      assert Decimal.equal?(statement.contributions, Decimal.new("50000"))
      assert Decimal.equal?(statement.distributions, Decimal.new("10000"))
      # ending = 100K + 50K - 10K = 140K
      assert Decimal.equal?(statement.ending_balance, Decimal.new("140000"))
      assert statement.status == "draft"
    end

    test "statement MOIC calculation is positive when value exceeds cost" do
      company = setup_fund_company()

      create_investor_contributions(company, "LP Delta", 100_000.0, "2024-01-01")
      create_investor_dividend(company, 20_000.0, "2025-06-15")

      statement =
        Fund.generate_investor_statement(
          company.id,
          "LP Delta",
          ~D[2025-01-01],
          ~D[2025-12-31]
        )

      # MOIC = (ending_balance + total_distributions) / total_contributions
      # ending = 100K + 0 contrib - 20K dist = 80K
      # total value = 80K + 20K = 100K, total contrib = 100K -> MOIC = 1.0
      assert Decimal.gt?(statement.moic, Decimal.new("0"))
    end

    test "investor statement can be persisted and updated through status workflow" do
      company = setup_fund_company()
      create_investor_contributions(company, "LP Echo", 200_000.0, "2024-06-01")

      statement_data =
        Fund.generate_investor_statement(
          company.id,
          "LP Echo",
          ~D[2025-01-01],
          ~D[2025-06-30]
        )

      {:ok, stmt} = Fund.create_investor_statement(statement_data)
      assert stmt.status == "draft"

      {:ok, reviewed} = Fund.update_investor_statement(stmt, %{status: "review"})
      assert reviewed.status == "review"

      {:ok, final} = Fund.update_investor_statement(reviewed, %{status: "final"})
      assert final.status == "final"
    end
  end

  # ===========================================================================
  # 6. K-1 Report Generation
  # ===========================================================================

  describe "K-1 report generation" do
    test "generate K-1 from distribution lines categorized by type" do
      company = setup_fund_company()

      # Profit distribution
      {:ok, profit_dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-09-15",
          total_amount: 100_000.0,
          distribution_type: "profit"
        })

      {:ok, _} =
        Fund.create_distribution_line(%{
          distribution_id: profit_dist.id,
          investor_name: "LP Alpha",
          gross_amount: 60_000.0,
          net_amount: 60_000.0
        })

      # Dividend distribution
      {:ok, div_dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-11-01",
          total_amount: 50_000.0,
          distribution_type: "dividend"
        })

      {:ok, _} =
        Fund.create_distribution_line(%{
          distribution_id: div_dist.id,
          investor_name: "LP Alpha",
          gross_amount: 30_000.0,
          net_amount: 30_000.0
        })

      {:ok, k1} = Fund.generate_k1(company.id, 2025, "LP Alpha")

      assert k1.tax_year == 2025
      assert k1.investor_name == "LP Alpha"
      assert k1.status == "draft"
      # profit -> long_term_capital_gains, dividend -> ordinary_income
      assert Decimal.equal?(k1.long_term_capital_gains, Decimal.new("60000.0"))
      assert Decimal.equal?(k1.ordinary_income, Decimal.new("30000.0"))
      assert Decimal.equal?(k1.total_distributions, Decimal.new("90000.0"))
    end

    test "K-1 status workflow: draft -> review -> final -> filed" do
      company = setup_fund_company()

      {:ok, k1} =
        Fund.create_k1_report(%{
          company_id: company.id,
          tax_year: 2025,
          investor_name: "LP Beta",
          ordinary_income: 10_000.0,
          status: "draft"
        })

      {:ok, reviewed} = Fund.update_k1_report(k1, %{status: "review"})
      assert reviewed.status == "review"

      {:ok, final} = Fund.update_k1_report(reviewed, %{status: "final"})
      assert final.status == "final"

      {:ok, filed} = Fund.update_k1_report(final, %{status: "filed"})
      assert filed.status == "filed"
    end

    test "K-1 with no distributions returns zero amounts" do
      company = setup_fund_company()

      {:ok, k1} = Fund.generate_k1(company.id, 2025, "LP Nonexistent")

      assert Decimal.equal?(k1.total_distributions, Decimal.new("0"))
      assert Decimal.equal?(k1.ordinary_income, Decimal.new("0"))
      assert Decimal.equal?(k1.long_term_capital_gains, Decimal.new("0"))
    end
  end

  # ===========================================================================
  # 7. Fee Calculations
  # ===========================================================================

  describe "fee calculations" do
    test "management fee calculated on NAV basis" do
      company = setup_fund_company()

      # Set up some assets so NAV is nonzero
      {:ok, _ba} =
        Banking.create_bank_account(%{
          company_id: company.id,
          bank_name: "Fund Account",
          balance: 1_000_000.0
        })

      fee_data =
        Fund.calculate_management_fee(
          company.id,
          2.0,
          "nav",
          ~D[2025-01-01],
          ~D[2025-12-31]
        )

      assert fee_data.fee_type == "management"
      assert fee_data.basis == "nav"
      assert Decimal.gt?(fee_data.amount, Decimal.new("0"))
      # 2% of 1M = $20K (prorated for ~365 days)
      assert Decimal.equal?(fee_data.calculation_basis_amount, Decimal.new("1000000"))
    end

    test "fee summary aggregates by type and status" do
      company = setup_fund_company()

      {:ok, _} =
        Fund.create_fund_fee(%{
          company_id: company.id,
          fee_type: "management",
          amount: 20_000.0,
          status: "accrued"
        })

      {:ok, _} =
        Fund.create_fund_fee(%{
          company_id: company.id,
          fee_type: "performance",
          amount: 50_000.0,
          status: "paid",
          paid_date: "2025-06-30"
        })

      {:ok, _} =
        Fund.create_fund_fee(%{
          company_id: company.id,
          fee_type: "management",
          amount: 20_000.0,
          status: "paid",
          paid_date: "2025-03-31"
        })

      summary = Fund.fee_summary(company.id)
      assert Map.has_key?(summary, :by_type)
      assert Map.has_key?(summary, :by_status)
      assert Map.has_key?(summary, :total)

      # Management fees total 40K
      mgmt_total = summary.by_type["management"]
      assert Decimal.equal?(mgmt_total, Decimal.from_float(40_000.0))
    end

    test "all fee types are valid" do
      company = setup_fund_company()

      for fee_type <- ~w(management performance admin custody legal audit other) do
        {:ok, fee} =
          Fund.create_fund_fee(%{
            company_id: company.id,
            fee_type: fee_type,
            amount: 1000.0
          })

        assert fee.fee_type == fee_type
      end
    end
  end

  # ===========================================================================
  # 8. Dividend Policy
  # ===========================================================================

  describe "dividend policy execution" do
    test "fixed amount policy recommends correct dividend" do
      company = setup_fund_company()

      # Create financials for the company
      {:ok, _fin} =
        Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 500_000.0,
          expenses: 300_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "Fixed Quarterly",
          policy_type: "fixed_amount",
          fixed_amount: 25_000.0,
          frequency: "quarterly"
        })

      result = Fund.calculate_dividend(policy, company.id)

      assert Decimal.equal?(result.recommended_amount, Decimal.new("25000.00"))
      # Net income = 500K - 300K = 200K, payout = 25K/200K = 12.5%
      assert Decimal.gt?(result.payout_ratio, Decimal.new("0"))
      assert Decimal.gt?(result.retained_earnings, Decimal.new("0"))
    end

    test "payout ratio policy calculates from net income" do
      company = setup_fund_company()

      {:ok, _fin} =
        Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q2",
          revenue: 1_000_000.0,
          expenses: 600_000.0
        })

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "50% Payout",
          policy_type: "payout_ratio",
          target_payout_ratio: 50.0,
          frequency: "quarterly"
        })

      result = Fund.calculate_dividend(policy, company.id)

      # Net income = 400K, 50% = 200K
      assert Decimal.equal?(result.recommended_amount, Decimal.new("200000.00"))
    end

    test "advance_dividend_date updates dates correctly" do
      company = setup_fund_company()

      {:ok, policy} =
        Fund.create_dividend_policy(%{
          company_id: company.id,
          name: "Quarterly",
          policy_type: "fixed_amount",
          fixed_amount: 10_000.0,
          frequency: "quarterly"
        })

      {:ok, advanced} = Fund.advance_dividend_date(policy)
      assert advanced.last_dividend_date == Date.utc_today()
      assert advanced.next_dividend_date != nil
      assert Date.diff(advanced.next_dividend_date, Date.utc_today()) > 80
    end
  end

  # ===========================================================================
  # 9. Fundraising Pipeline to Capital Call End-to-End
  # ===========================================================================

  describe "fundraising pipeline to capital call flow" do
    test "prospect committed -> pipeline closing -> capital call issued" do
      company = setup_fund_company()

      # Create fundraising pipeline
      {:ok, pipeline} =
        Fund.create_fundraising_pipeline(%{
          company_id: company.id,
          fund_name: "Acme Fund II",
          target_amount: 50_000_000.0,
          management_fee_rate: 2.0,
          carried_interest_rate: 20.0,
          hurdle_rate: 8.0,
          fund_term_years: 10
        })

      assert pipeline.status == "prospecting"

      # Add prospects
      {:ok, p1} =
        Fund.create_prospect(%{
          pipeline_id: pipeline.id,
          investor_name: "Sovereign Wealth Fund A",
          contact_email: "swf@example.com",
          commitment_amount: 20_000_000.0,
          status: "identified"
        })

      {:ok, p2} =
        Fund.create_prospect(%{
          pipeline_id: pipeline.id,
          investor_name: "Pension Fund B",
          contact_email: "pfb@example.com",
          commitment_amount: 15_000_000.0,
          status: "identified"
        })

      # Move prospects through stages
      {:ok, _} = Fund.update_prospect(p1, %{status: "contacted"})
      {:ok, _} = Fund.update_prospect(p1, %{status: "interested"})
      {:ok, p1_committed} = Fund.update_prospect(p1, %{status: "committed"})
      assert p1_committed.status == "committed"

      {:ok, p2_committed} = Fund.update_prospect(p2, %{status: "committed"})
      assert p2_committed.status == "committed"

      # Update pipeline
      {:ok, closing} =
        Fund.update_fundraising_pipeline(pipeline, %{
          status: "closing",
          amount_raised: 35_000_000.0,
          first_close_date: "2025-06-01"
        })

      assert closing.status == "closing"

      # Issue capital call for first close
      {:ok, cc} =
        Fund.create_capital_call(%{
          company_id: company.id,
          call_date: "2025-06-01",
          due_date: "2025-07-01",
          total_amount: 8_750_000.0,
          purpose: "investment",
          status: "pending"
        })

      assert cc.total_amount |> Decimal.equal?(Decimal.from_float(8_750_000.0))

      # Pipeline summary
      summary = Fund.pipeline_summary(pipeline.id)
      assert summary.committed_count >= 2
    end
  end

  # ===========================================================================
  # 10. Partnership Basis Tracking
  # ===========================================================================

  describe "partnership basis tracking" do
    test "create and calculate ending basis" do
      company = setup_fund_company()

      {:ok, pb} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "LP Alpha",
          tax_year: 2025,
          beginning_basis: 500_000.0,
          capital_contributions: 100_000.0,
          share_of_income: 75_000.0,
          share_of_losses: 10_000.0,
          distributions_received: 50_000.0
        })

      ending = Fund.calculate_ending_basis(pb)
      # ending = 500K + 100K + 75K - 10K - 50K = 615K
      assert Decimal.equal?(ending, Decimal.new("615000"))
    end

    test "basis history tracks year over year" do
      company = setup_fund_company()

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "LP Alpha",
          tax_year: 2023,
          beginning_basis: 500_000.0,
          ending_basis: 550_000.0
        })

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "LP Alpha",
          tax_year: 2024,
          beginning_basis: 550_000.0,
          ending_basis: 600_000.0
        })

      history = Fund.basis_history(company.id, "LP Alpha")
      assert length(history) == 2
      # Ordered by ascending tax year
      years = Enum.map(history, & &1.tax_year)
      assert years == [2023, 2024]
    end
  end

  # ===========================================================================
  # 11. Cross-Context Integration: Capital Call -> Statement -> K-1
  # ===========================================================================

  describe "cross-context integration" do
    test "full flow: contribute capital -> distribute profit -> generate statement and K-1" do
      company = setup_fund_company()

      # Step 1: Capital contribution
      create_investor_contributions(company, "LP Full", 500_000.0, "2024-01-15")

      # Step 2: Distribution
      {:ok, dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-06-15",
          total_amount: 100_000.0,
          distribution_type: "profit"
        })

      {:ok, _dl} =
        Fund.create_distribution_line(%{
          distribution_id: dist.id,
          investor_name: "LP Full",
          gross_amount: 100_000.0,
          net_amount: 100_000.0
        })

      # Also record as a finance dividend for the statement
      create_investor_dividend(company, 100_000.0, "2025-06-15")

      # Step 3: Generate investor statement
      statement =
        Fund.generate_investor_statement(
          company.id,
          "LP Full",
          ~D[2025-01-01],
          ~D[2025-12-31]
        )

      assert Decimal.equal?(statement.beginning_balance, Decimal.new("500000"))
      assert Decimal.equal?(statement.distributions, Decimal.new("100000"))
      assert Decimal.equal?(statement.ending_balance, Decimal.new("400000"))

      # Step 4: Generate K-1
      {:ok, k1} = Fund.generate_k1(company.id, 2025, "LP Full")
      assert Decimal.equal?(k1.total_distributions, Decimal.new("100000.0"))
      assert Decimal.equal?(k1.long_term_capital_gains, Decimal.new("100000.0"))
    end

    test "capital call funded -> NAV reflects new bank balance -> fee on NAV" do
      company = setup_fund_company()

      # Fund receives $1M in bank
      {:ok, _ba} =
        Banking.create_bank_account(%{
          company_id: company.id,
          bank_name: "Fund Operating Account",
          balance: 1_000_000.0
        })

      # NAV should reflect bank balance
      nav = Fund.calculate_fund_nav(company.id)
      assert Decimal.equal?(nav.net_asset_value, Decimal.new("1000000"))

      # Calculate management fee on NAV
      fee_data =
        Fund.calculate_management_fee(
          company.id,
          2.0,
          "nav",
          ~D[2025-01-01],
          ~D[2025-12-31]
        )

      # 2% of $1M prorated for ~365 days = ~$20K
      assert Decimal.gt?(fee_data.amount, Decimal.new("19000"))
      assert Decimal.lt?(fee_data.amount, Decimal.new("21000"))
    end
  end
end
