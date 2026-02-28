defmodule Holdco.FundTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund
  alias Holdco.Money

  # ── Capital Call CRUD ──────────────────────────────────

  describe "list_capital_calls/1" do
    test "returns all capital calls" do
      cc = capital_call_fixture()
      calls = Fund.list_capital_calls()
      assert length(calls) >= 1
      assert Enum.any?(calls, &(&1.id == cc.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "FundCo1"})
      c2 = company_fixture(%{name: "FundCo2"})
      cc1 = capital_call_fixture(%{company: c1})
      _cc2 = capital_call_fixture(%{company: c2})

      calls = Fund.list_capital_calls(c1.id)
      assert length(calls) == 1
      assert hd(calls).id == cc1.id
    end

    test "returns empty list when no calls for company" do
      company = company_fixture()
      assert Fund.list_capital_calls(company.id) == []
    end
  end

  describe "get_capital_call!/1" do
    test "returns the capital call with given id" do
      cc = capital_call_fixture()
      found = Fund.get_capital_call!(cc.id)
      assert found.id == cc.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_capital_call!(0)
      end
    end
  end

  describe "create_capital_call/1" do
    test "creates a capital call with valid attrs" do
      company = company_fixture()

      assert {:ok, cc} =
               Fund.create_capital_call(%{
                 company_id: company.id,
                 call_date: "2025-03-01",
                 total_amount: 100_000.0,
                 purpose: "investment"
               })

      assert cc.purpose == "investment"
      assert Decimal.equal?(cc.total_amount, Decimal.from_float(100_000.0))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_capital_call(%{})
      assert %{call_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates purpose inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_capital_call(%{
                 company_id: company.id,
                 call_date: "2025-03-01",
                 total_amount: 100_000.0,
                 purpose: "invalid_purpose"
               })

      assert %{purpose: _} = errors_on(changeset)
    end
  end

  describe "update_capital_call/2" do
    test "updates a capital call" do
      cc = capital_call_fixture()
      assert {:ok, updated} = Fund.update_capital_call(cc, %{status: "funded"})
      assert updated.status == "funded"
    end
  end

  describe "delete_capital_call/1" do
    test "deletes the capital call" do
      cc = capital_call_fixture()
      assert {:ok, _} = Fund.delete_capital_call(cc)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_capital_call!(cc.id)
      end
    end
  end

  # ── Capital Call Line Payment Flow ─────────────────────

  describe "capital call line payment flow" do
    test "creates a capital call line" do
      cc = capital_call_fixture()

      assert {:ok, line} =
               Fund.create_capital_call_line(%{
                 capital_call_id: cc.id,
                 investor_name: "Investor A",
                 commitment_amount: 1_000_000.0,
                 call_amount: 250_000.0
               })

      assert line.investor_name == "Investor A"
      assert line.status == "pending"
    end

    test "marks a line as paid" do
      cc = capital_call_fixture()

      {:ok, line} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "Investor B",
          call_amount: 100_000.0
        })

      assert {:ok, paid_line} = Fund.mark_line_paid(line, Decimal.new("100000"))
      assert paid_line.status == "paid"
      assert paid_line.paid_date == Date.utc_today()
    end

    test "marking all lines paid updates call to funded" do
      cc = capital_call_fixture()

      {:ok, line1} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "Investor C",
          call_amount: 250_000.0
        })

      {:ok, line2} =
        Fund.create_capital_call_line(%{
          capital_call_id: cc.id,
          investor_name: "Investor D",
          call_amount: 250_000.0
        })

      Fund.mark_line_paid(line1, Decimal.new("250000"))
      Fund.mark_line_paid(line2, Decimal.new("250000"))

      updated_call = Fund.get_capital_call!(cc.id)
      assert updated_call.status == "funded"
    end
  end

  # ── Distribution CRUD ──────────────────────────────────

  describe "list_distributions/1" do
    test "returns all distributions" do
      dist = distribution_fixture()
      distributions = Fund.list_distributions()
      assert length(distributions) >= 1
      assert Enum.any?(distributions, &(&1.id == dist.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "DistCo1"})
      c2 = company_fixture(%{name: "DistCo2"})
      d1 = distribution_fixture(%{company: c1})
      _d2 = distribution_fixture(%{company: c2})

      dists = Fund.list_distributions(c1.id)
      assert length(dists) == 1
      assert hd(dists).id == d1.id
    end
  end

  describe "create_distribution/1" do
    test "creates a distribution with valid attrs" do
      company = company_fixture()

      assert {:ok, dist} =
               Fund.create_distribution(%{
                 company_id: company.id,
                 distribution_date: "2025-06-01",
                 total_amount: 500_000.0,
                 distribution_type: "profit"
               })

      assert dist.distribution_type == "profit"
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_distribution(%{})
      assert %{distribution_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates distribution_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_distribution(%{
                 company_id: company.id,
                 distribution_date: "2025-06-01",
                 total_amount: 100.0,
                 distribution_type: "invalid"
               })

      assert %{distribution_type: _} = errors_on(changeset)
    end
  end

  describe "update_distribution/2" do
    test "updates a distribution" do
      dist = distribution_fixture()
      assert {:ok, updated} = Fund.update_distribution(dist, %{status: "approved"})
      assert updated.status == "approved"
    end
  end

  # ── Distribution Line Calculation ──────────────────────

  describe "distribution line operations" do
    test "creates a distribution line" do
      dist = distribution_fixture()

      assert {:ok, line} =
               Fund.create_distribution_line(%{
                 distribution_id: dist.id,
                 investor_name: "LP Alpha",
                 ownership_pct: 50.0,
                 gross_amount: 100_000.0,
                 withholding_tax: 10_000.0,
                 net_amount: 90_000.0
               })

      assert line.investor_name == "LP Alpha"
      assert Decimal.equal?(line.net_amount, Decimal.from_float(90_000.0))
    end

    test "auto-calculates distribution lines for investors" do
      company = company_fixture()

      {:ok, dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-06-01",
          total_amount: 1_000_000.0,
          distribution_type: "profit"
        })

      investors = [
        %{investor_name: "LP Alpha", ownership_pct: 60, withholding_tax_rate: 0.1},
        %{investor_name: "LP Beta", ownership_pct: 40, withholding_tax_rate: 0.15}
      ]

      results = Fund.calculate_distribution_lines(dist.id, investors)

      assert length(results) == 2
      [{:ok, alpha_line}, {:ok, beta_line}] = results

      # LP Alpha: 60% of 1M = 600K gross, 60K withholding, 540K net
      assert Money.equal?(alpha_line.gross_amount, 600_000)
      assert Money.equal?(alpha_line.withholding_tax, 60_000)
      assert Money.equal?(alpha_line.net_amount, 540_000)

      # LP Beta: 40% of 1M = 400K gross, 60K withholding, 340K net
      assert Money.equal?(beta_line.gross_amount, 400_000)
      assert Money.equal?(beta_line.withholding_tax, 60_000)
      assert Money.equal?(beta_line.net_amount, 340_000)
    end

    test "deletes a distribution line" do
      line = distribution_line_fixture()
      assert {:ok, _} = Fund.delete_distribution_line(line)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_distribution_line!(line.id)
      end
    end
  end

  # ── Waterfall Tier CRUD ────────────────────────────────

  describe "waterfall tier CRUD" do
    test "creates a waterfall tier" do
      company = company_fixture()

      assert {:ok, tier} =
               Fund.create_waterfall_tier(%{
                 company_id: company.id,
                 tier_order: 1,
                 name: "Return of Capital",
                 tier_type: "return_of_capital",
                 split_lp_pct: 100.0,
                 split_gp_pct: 0.0
               })

      assert tier.name == "Return of Capital"
      assert tier.tier_type == "return_of_capital"
    end

    test "lists waterfall tiers for a company ordered by tier_order" do
      company = company_fixture()

      waterfall_tier_fixture(%{company: company, tier_order: 2, name: "Preferred Return", tier_type: "preferred_return"})
      waterfall_tier_fixture(%{company: company, tier_order: 1, name: "Return of Capital", tier_type: "return_of_capital"})

      tiers = Fund.list_waterfall_tiers(company.id)
      assert length(tiers) == 2
      assert hd(tiers).tier_order == 1
      assert List.last(tiers).tier_order == 2
    end

    test "deletes a waterfall tier" do
      tier = waterfall_tier_fixture()
      assert {:ok, _} = Fund.delete_waterfall_tier(tier)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_waterfall_tier!(tier.id)
      end
    end
  end

  # ── Waterfall Calculation ──────────────────────────────

  describe "calculate_waterfall/3" do
    test "simple return of capital only" do
      company = company_fixture()

      {:ok, tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 1,
          name: "Return of Capital",
          tier_type: "return_of_capital"
        })

      results = Fund.calculate_waterfall(1_000_000, 800_000, [tier])

      assert length(results) == 1
      roc = hd(results)
      assert roc.tier_name == "Return of Capital"
      # LP gets back 800K (their contributed capital)
      assert Money.equal?(roc.lp_amount, 800_000)
      assert Money.equal?(roc.gp_amount, 0)
    end

    test "multi-tier waterfall: ROC + preferred + residual" do
      company = company_fixture()

      {:ok, roc_tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 1,
          name: "Return of Capital",
          tier_type: "return_of_capital"
        })

      {:ok, pref_tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 2,
          name: "8% Preferred Return",
          tier_type: "preferred_return",
          hurdle_rate: 0.08
        })

      {:ok, residual_tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 3,
          name: "80/20 Split",
          tier_type: "residual",
          split_lp_pct: 80.0,
          split_gp_pct: 20.0
        })

      # Distribute 1.5M with 1M contributed capital
      results = Fund.calculate_waterfall(1_500_000, 1_000_000, [roc_tier, pref_tier, residual_tier])

      assert length(results) == 3
      [roc, pref, residual] = results

      # Tier 1: LP gets 1M back (return of capital)
      assert Money.equal?(roc.lp_amount, 1_000_000)
      assert Money.equal?(roc.gp_amount, 0)

      # Tier 2: LP gets 8% of 1M = 80K preferred return
      assert Money.equal?(pref.lp_amount, 80_000)
      assert Money.equal?(pref.gp_amount, 0)

      # Tier 3: Remaining 420K split 80/20
      # LP: 336K, GP: 84K
      assert Money.equal?(residual.lp_amount, 336_000)
      assert Money.equal?(residual.gp_amount, 84_000)
    end

    test "waterfall with insufficient distributable amount" do
      company = company_fixture()

      {:ok, roc_tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 1,
          name: "Return of Capital",
          tier_type: "return_of_capital"
        })

      {:ok, pref_tier} =
        Fund.create_waterfall_tier(%{
          company_id: company.id,
          tier_order: 2,
          name: "Preferred Return",
          tier_type: "preferred_return",
          hurdle_rate: 0.08
        })

      # Distribute only 500K against 1M capital - not enough to even return all capital
      results = Fund.calculate_waterfall(500_000, 1_000_000, [roc_tier, pref_tier])

      [roc, pref] = results

      # LP gets only 500K back (all available goes to ROC)
      assert Money.equal?(roc.lp_amount, 500_000)
      # Nothing left for preferred
      assert Money.equal?(pref.lp_amount, 0)
      assert Money.equal?(pref.gp_amount, 0)
    end
  end

  # ── K-1 Generation ─────────────────────────────────────

  describe "generate_k1/3" do
    test "generates K-1 from distribution data" do
      company = company_fixture()

      # Create a dividend distribution
      {:ok, div_dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-06-15",
          total_amount: 100_000.0,
          distribution_type: "dividend"
        })

      {:ok, _div_line} =
        Fund.create_distribution_line(%{
          distribution_id: div_dist.id,
          investor_name: "Investor K1",
          gross_amount: 50_000.0,
          net_amount: 45_000.0
        })

      # Create a profit distribution
      {:ok, profit_dist} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-09-15",
          total_amount: 200_000.0,
          distribution_type: "profit"
        })

      {:ok, _profit_line} =
        Fund.create_distribution_line(%{
          distribution_id: profit_dist.id,
          investor_name: "Investor K1",
          gross_amount: 100_000.0,
          net_amount: 90_000.0
        })

      assert {:ok, k1} = Fund.generate_k1(company.id, 2025, "Investor K1")

      assert k1.tax_year == 2025
      assert k1.investor_name == "Investor K1"
      assert k1.status == "draft"
      # Dividend goes to ordinary income
      assert Money.equal?(k1.ordinary_income, 45_000)
      # Profit goes to long-term capital gains
      assert Money.equal?(k1.long_term_capital_gains, 90_000)
      # Total distributions = 45K + 90K = 135K
      assert Money.equal?(k1.total_distributions, 135_000)
    end

    test "generates K-1 with no distributions returns zeros" do
      company = company_fixture()

      assert {:ok, k1} = Fund.generate_k1(company.id, 2025, "No Distributions Investor")
      assert k1.investor_name == "No Distributions Investor"
      assert Money.equal?(k1.total_distributions, 0)
      assert Money.equal?(k1.ordinary_income, 0)
    end

    test "K-1 generation only includes specified tax year" do
      company = company_fixture()

      {:ok, dist_2024} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2024-06-15",
          total_amount: 100_000.0,
          distribution_type: "dividend"
        })

      {:ok, _line_2024} =
        Fund.create_distribution_line(%{
          distribution_id: dist_2024.id,
          investor_name: "Year Filter Investor",
          gross_amount: 50_000.0,
          net_amount: 50_000.0
        })

      {:ok, dist_2025} =
        Fund.create_distribution(%{
          company_id: company.id,
          distribution_date: "2025-03-15",
          total_amount: 200_000.0,
          distribution_type: "profit"
        })

      {:ok, _line_2025} =
        Fund.create_distribution_line(%{
          distribution_id: dist_2025.id,
          investor_name: "Year Filter Investor",
          gross_amount: 75_000.0,
          net_amount: 75_000.0
        })

      # Generate for 2025 only
      assert {:ok, k1} = Fund.generate_k1(company.id, 2025, "Year Filter Investor")
      # Should only have 2025 data (75K profit -> long term gains)
      assert Money.equal?(k1.long_term_capital_gains, 75_000)
      assert Money.equal?(k1.total_distributions, 75_000)
    end
  end

  # ── K-1 CRUD ───────────────────────────────────────────

  describe "K-1 CRUD" do
    test "creates a K-1 report" do
      company = company_fixture()

      assert {:ok, k1} =
               Fund.create_k1_report(%{
                 company_id: company.id,
                 tax_year: 2025,
                 investor_name: "Manual K1 Investor",
                 ordinary_income: 100_000.0,
                 long_term_capital_gains: 50_000.0
               })

      assert k1.investor_name == "Manual K1 Investor"
      assert k1.status == "draft"
    end

    test "lists K-1 reports" do
      k1 = k1_report_fixture()
      reports = Fund.list_k1_reports()
      assert Enum.any?(reports, &(&1.id == k1.id))
    end

    test "updates a K-1 report status" do
      k1 = k1_report_fixture()
      assert {:ok, updated} = Fund.update_k1_report(k1, %{status: "final"})
      assert updated.status == "final"
    end

    test "deletes a K-1 report" do
      k1 = k1_report_fixture()
      assert {:ok, _} = Fund.delete_k1_report(k1)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_k1_report!(k1.id)
      end
    end

    test "validates K-1 status inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_k1_report(%{
                 company_id: company.id,
                 tax_year: 2025,
                 investor_name: "Bad Status",
                 status: "invalid_status"
               })

      assert %{status: _} = errors_on(changeset)
    end
  end
end
