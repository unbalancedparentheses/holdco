defmodule Holdco.TaxTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Tax
  alias Holdco.Money

  # ── Jurisdiction CRUD ──────────────────────────────────

  describe "jurisdictions" do
    test "list_jurisdictions/0 returns all jurisdictions ordered by name" do
      j1 = jurisdiction_fixture(%{name: "Zurich", country_code: "CH"})
      j2 = jurisdiction_fixture(%{name: "Bermuda", country_code: "BM"})

      result = Tax.list_jurisdictions()
      ids = Enum.map(result, & &1.id)

      assert j2.id in ids
      assert j1.id in ids
      # Bermuda should come before Zurich alphabetically
      idx_b = Enum.find_index(result, &(&1.id == j2.id))
      idx_z = Enum.find_index(result, &(&1.id == j1.id))
      assert idx_b < idx_z
    end

    test "get_jurisdiction!/1 returns the jurisdiction" do
      j = jurisdiction_fixture()
      fetched = Tax.get_jurisdiction!(j.id)
      assert fetched.id == j.id
      assert fetched.name == j.name
    end

    test "get_jurisdiction!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Tax.get_jurisdiction!(999_999)
      end
    end

    test "create_jurisdiction/1 with valid attrs creates a jurisdiction" do
      attrs = %{
        name: "Ireland",
        country_code: "IE",
        tax_rate: 0.125,
        tax_type: "income",
        effective_date: "2024-01-01",
        is_active: true
      }

      assert {:ok, j} = Tax.create_jurisdiction(attrs)
      assert j.name == "Ireland"
      assert j.country_code == "IE"
      assert Decimal.equal?(j.tax_rate, Decimal.from_float(0.125))
      assert j.tax_type == "income"
      assert j.is_active == true
    end

    test "create_jurisdiction/1 fails with missing required fields" do
      assert {:error, changeset} = Tax.create_jurisdiction(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:country_code]
      assert errors[:tax_rate]
      assert errors[:tax_type]
    end

    test "create_jurisdiction/1 fails with invalid tax_type" do
      attrs = %{name: "Test", country_code: "XX", tax_rate: 0.1, tax_type: "invalid"}
      assert {:error, changeset} = Tax.create_jurisdiction(attrs)
      assert "is invalid" in errors_on(changeset)[:tax_type]
    end

    test "create_jurisdiction/1 fails with tax_rate above 1" do
      attrs = %{name: "Test", country_code: "XX", tax_rate: 1.5, tax_type: "income"}
      assert {:error, changeset} = Tax.create_jurisdiction(attrs)
      assert errors_on(changeset)[:tax_rate]
    end

    test "create_jurisdiction/1 fails with negative tax_rate" do
      attrs = %{name: "Test", country_code: "XX", tax_rate: -0.1, tax_type: "income"}
      assert {:error, changeset} = Tax.create_jurisdiction(attrs)
      assert errors_on(changeset)[:tax_rate]
    end

    test "create_jurisdiction/1 accepts all valid tax_types" do
      for tax_type <- ~w(income capital_gains withholding vat) do
        attrs = %{
          name: "Test #{tax_type}",
          country_code: "XX",
          tax_rate: 0.1,
          tax_type: tax_type
        }

        assert {:ok, _} = Tax.create_jurisdiction(attrs)
      end
    end

    test "update_jurisdiction/2 updates the jurisdiction" do
      j = jurisdiction_fixture(%{name: "Old Name", tax_rate: 0.2})
      assert {:ok, updated} = Tax.update_jurisdiction(j, %{name: "New Name", tax_rate: 0.15})
      assert updated.name == "New Name"
      assert Decimal.equal?(updated.tax_rate, Decimal.from_float(0.15))
    end

    test "update_jurisdiction/2 fails with invalid data" do
      j = jurisdiction_fixture()
      assert {:error, _} = Tax.update_jurisdiction(j, %{tax_type: "bogus"})
    end

    test "delete_jurisdiction/1 removes the jurisdiction" do
      j = jurisdiction_fixture()
      assert {:ok, _} = Tax.delete_jurisdiction(j)
      assert_raise Ecto.NoResultsError, fn -> Tax.get_jurisdiction!(j.id) end
    end

    test "create_jurisdiction/1 validates effective_date format" do
      attrs = %{name: "Test", country_code: "XX", tax_rate: 0.1, tax_type: "income", effective_date: "not-a-date"}
      assert {:error, changeset} = Tax.create_jurisdiction(attrs)
      assert errors_on(changeset)[:effective_date]
    end

    test "create_jurisdiction/1 accepts valid dates" do
      attrs = %{name: "Test", country_code: "XX", tax_rate: 0.1, tax_type: "income", effective_date: "2025-01-01", expiry_date: "2026-12-31"}
      assert {:ok, j} = Tax.create_jurisdiction(attrs)
      assert j.effective_date == "2025-01-01"
      assert j.expiry_date == "2026-12-31"
    end
  end

  # ── Optimize Tax Structure ─────────────────────────────

  describe "optimize_tax_structure/1" do
    test "returns optimization results for a company" do
      company = company_fixture(%{country: "US"})
      _holding = holding_fixture(%{company: company, asset: "AAPL", quantity: 100.0})

      jurisdiction_fixture(%{name: "US Federal", country_code: "US", tax_rate: 0.21, tax_type: "income"})
      jurisdiction_fixture(%{name: "Ireland", country_code: "IE", tax_rate: 0.125, tax_type: "income"})

      result = Tax.optimize_tax_structure(company.id)

      assert result.company_id == company.id
      assert is_integer(result.holdings_count)
      assert is_list(result.jurisdiction_analysis)
      assert is_list(result.suggestions)
    end

    test "returns empty analysis when no jurisdictions exist" do
      company = company_fixture()
      result = Tax.optimize_tax_structure(company.id)

      assert result.company_id == company.id
      assert result.jurisdiction_analysis == []
      assert result.suggestions == []
    end

    test "suggests lower-rate jurisdictions" do
      company = company_fixture(%{country: "US"})
      _holding = holding_fixture(%{company: company, asset: "Stock", quantity: 1000.0})

      jurisdiction_fixture(%{name: "US", country_code: "US", tax_rate: 0.35, tax_type: "income"})
      jurisdiction_fixture(%{name: "Cayman", country_code: "KY", tax_rate: 0.0, tax_type: "income"})

      result = Tax.optimize_tax_structure(company.id)

      income_suggestion = Enum.find(result.suggestions, &(&1.tax_type == "income"))
      assert income_suggestion
      assert income_suggestion.recommended_country == "KY"
    end

    test "includes holdings count" do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "A", quantity: 10.0})
      holding_fixture(%{company: company, asset: "B", quantity: 20.0})

      result = Tax.optimize_tax_structure(company.id)
      assert result.holdings_count == 2
    end

    test "handles company with no holdings" do
      company = company_fixture()
      result = Tax.optimize_tax_structure(company.id)

      assert result.holdings_count == 0
      assert Decimal.equal?(result.total_portfolio_value, Decimal.new(0))
    end
  end

  # ── Withholding Reclaims CRUD ──────────────────────────

  describe "withholding reclaims" do
    test "list_withholding_reclaims/1 returns reclaims for a company" do
      company = company_fixture()
      r1 = withholding_reclaim_fixture(%{company: company, jurisdiction: "DE"})
      r2 = withholding_reclaim_fixture(%{company: company, jurisdiction: "FR"})

      other_company = company_fixture()
      _r3 = withholding_reclaim_fixture(%{company: other_company})

      reclaims = Tax.list_withholding_reclaims(company.id)
      ids = Enum.map(reclaims, & &1.id)
      assert r1.id in ids
      assert r2.id in ids
      assert length(reclaims) == 2
    end

    test "get_withholding_reclaim!/1 returns the reclaim with preloaded company" do
      reclaim = withholding_reclaim_fixture()
      fetched = Tax.get_withholding_reclaim!(reclaim.id)
      assert fetched.id == reclaim.id
      assert fetched.company != nil
    end

    test "create_withholding_reclaim/1 with valid attrs" do
      company = company_fixture()

      attrs = %{
        company_id: company.id,
        jurisdiction: "CH",
        tax_year: 2025,
        income_type: "interest",
        gross_amount: 50000.0,
        withholding_rate: 0.35,
        amount_withheld: 17500.0,
        treaty_rate: 0.10,
        reclaimable_amount: 12500.0,
        status: "pending"
      }

      assert {:ok, reclaim} = Tax.create_withholding_reclaim(attrs)
      assert reclaim.jurisdiction == "CH"
      assert reclaim.income_type == "interest"
      assert reclaim.tax_year == 2025
    end

    test "create_withholding_reclaim/1 fails with missing required fields" do
      assert {:error, changeset} = Tax.create_withholding_reclaim(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:jurisdiction]
      assert errors[:income_type]
      assert errors[:gross_amount]
    end

    test "create_withholding_reclaim/1 validates income_type" do
      company = company_fixture()
      attrs = %{company_id: company.id, jurisdiction: "DE", tax_year: 2025, income_type: "invalid", gross_amount: 100.0, withholding_rate: 0.1, amount_withheld: 10.0}
      assert {:error, changeset} = Tax.create_withholding_reclaim(attrs)
      assert "is invalid" in errors_on(changeset)[:income_type]
    end

    test "create_withholding_reclaim/1 validates status" do
      company = company_fixture()
      attrs = %{company_id: company.id, jurisdiction: "DE", tax_year: 2025, income_type: "dividend", gross_amount: 100.0, withholding_rate: 0.1, amount_withheld: 10.0, status: "bogus"}
      assert {:error, changeset} = Tax.create_withholding_reclaim(attrs)
      assert "is invalid" in errors_on(changeset)[:status]
    end

    test "create_withholding_reclaim/1 accepts all valid income types" do
      company = company_fixture()

      for income_type <- ~w(dividend interest royalty) do
        attrs = %{
          company_id: company.id,
          jurisdiction: "DE",
          tax_year: 2025,
          income_type: income_type,
          gross_amount: 1000.0,
          withholding_rate: 0.15,
          amount_withheld: 150.0
        }

        assert {:ok, _} = Tax.create_withholding_reclaim(attrs)
      end
    end

    test "update_withholding_reclaim/2 updates the reclaim" do
      reclaim = withholding_reclaim_fixture()
      assert {:ok, updated} = Tax.update_withholding_reclaim(reclaim, %{status: "filed", filed_date: "2025-06-15"})
      assert updated.status == "filed"
      assert updated.filed_date == "2025-06-15"
    end

    test "update_withholding_reclaim/2 fails with invalid data" do
      reclaim = withholding_reclaim_fixture()
      assert {:error, _} = Tax.update_withholding_reclaim(reclaim, %{status: "bogus_status"})
    end

    test "delete_withholding_reclaim/1 removes the reclaim" do
      reclaim = withholding_reclaim_fixture()
      assert {:ok, _} = Tax.delete_withholding_reclaim(reclaim)
      assert_raise Ecto.NoResultsError, fn -> Tax.get_withholding_reclaim!(reclaim.id) end
    end
  end

  # ── Reclaim Summary ────────────────────────────────────

  describe "reclaim_summary/1" do
    test "returns summary grouped by status" do
      company = company_fixture()
      withholding_reclaim_fixture(%{company: company, status: "pending", amount_withheld: 1000.0, reclaimable_amount: 500.0})
      withholding_reclaim_fixture(%{company: company, status: "filed", amount_withheld: 2000.0, reclaimable_amount: 1000.0})
      withholding_reclaim_fixture(%{company: company, status: "pending", amount_withheld: 1500.0, reclaimable_amount: 750.0})

      summary = Tax.reclaim_summary(company.id)

      assert is_list(summary.by_status)
      pending = Enum.find(summary.by_status, &(&1.status == "pending"))
      assert pending.count == 2

      filed = Enum.find(summary.by_status, &(&1.status == "filed"))
      assert filed.count == 1
    end

    test "returns summary grouped by jurisdiction" do
      company = company_fixture()
      withholding_reclaim_fixture(%{company: company, jurisdiction: "DE", amount_withheld: 1000.0})
      withholding_reclaim_fixture(%{company: company, jurisdiction: "DE", amount_withheld: 2000.0})
      withholding_reclaim_fixture(%{company: company, jurisdiction: "FR", amount_withheld: 500.0})

      summary = Tax.reclaim_summary(company.id)

      assert is_list(summary.by_jurisdiction)
      de = Enum.find(summary.by_jurisdiction, &(&1.jurisdiction == "DE"))
      assert de.count == 2
    end

    test "computes totals correctly" do
      company = company_fixture()
      withholding_reclaim_fixture(%{company: company, amount_withheld: 1000.0, reclaimable_amount: 500.0, reclaimed_amount: 200.0})
      withholding_reclaim_fixture(%{company: company, amount_withheld: 2000.0, reclaimable_amount: 1000.0, reclaimed_amount: 800.0})

      summary = Tax.reclaim_summary(company.id)

      assert Money.equal?(summary.total_withheld, Decimal.new(3000))
      assert Money.equal?(summary.total_reclaimable, Decimal.new(1500))
      assert Money.equal?(summary.total_reclaimed, Decimal.new(1000))
    end

    test "computes recovery rate" do
      company = company_fixture()
      withholding_reclaim_fixture(%{company: company, reclaimable_amount: 1000.0, reclaimed_amount: 500.0})

      summary = Tax.reclaim_summary(company.id)
      # 500 / 1000 = 0.5
      assert Money.equal?(summary.recovery_rate, Decimal.from_float(0.5))
    end

    test "returns zero recovery_rate when nothing reclaimable" do
      company = company_fixture()
      withholding_reclaim_fixture(%{company: company, reclaimable_amount: 0.0, reclaimed_amount: 0.0})

      summary = Tax.reclaim_summary(company.id)
      assert Decimal.equal?(summary.recovery_rate, Decimal.new(0))
    end

    test "returns empty summary for company with no reclaims" do
      company = company_fixture()
      summary = Tax.reclaim_summary(company.id)

      assert summary.by_status == []
      assert summary.by_jurisdiction == []
      assert Decimal.equal?(summary.total_withheld, Decimal.new(0))
    end
  end

  # ── Repatriation Plans CRUD ────────────────────────────

  describe "repatriation plans" do
    test "list_repatriation_plans/1 returns plans for a company" do
      company = company_fixture()
      p1 = repatriation_plan_fixture(%{company: company, source_jurisdiction: "IE"})
      p2 = repatriation_plan_fixture(%{company: company, source_jurisdiction: "DE"})

      other = company_fixture()
      _p3 = repatriation_plan_fixture(%{company: other})

      plans = Tax.list_repatriation_plans(company.id)
      ids = Enum.map(plans, & &1.id)
      assert p1.id in ids
      assert p2.id in ids
      assert length(plans) == 2
    end

    test "get_repatriation_plan!/1 returns the plan" do
      plan = repatriation_plan_fixture()
      fetched = Tax.get_repatriation_plan!(plan.id)
      assert fetched.id == plan.id
      assert fetched.company != nil
    end

    test "create_repatriation_plan/1 with valid attrs" do
      company = company_fixture()

      attrs = %{
        company_id: company.id,
        source_jurisdiction: "SG",
        target_jurisdiction: "US",
        amount: 500000.0,
        currency: "USD",
        mechanism: "management_fee",
        withholding_tax_rate: 0.10,
        planned_date: "2026-06-15",
        status: "draft"
      }

      assert {:ok, plan} = Tax.create_repatriation_plan(attrs)
      assert plan.source_jurisdiction == "SG"
      assert plan.mechanism == "management_fee"
      # Auto-calculated fields
      assert Money.gt?(plan.withholding_tax_amount, 0)
      assert Money.gt?(plan.net_amount, 0)
    end

    test "create_repatriation_plan/1 auto-calculates withholding and net amount" do
      company = company_fixture()

      attrs = %{
        company_id: company.id,
        source_jurisdiction: "DE",
        target_jurisdiction: "US",
        amount: 100000.0,
        mechanism: "dividend",
        withholding_tax_rate: 0.15
      }

      assert {:ok, plan} = Tax.create_repatriation_plan(attrs)
      # 100000 * 0.15 = 15000
      assert Money.equal?(plan.withholding_tax_amount, Decimal.new(15000))
      # 100000 - 15000 = 85000
      assert Money.equal?(plan.net_amount, Decimal.new(85000))
    end

    test "create_repatriation_plan/1 fails with missing required fields" do
      assert {:error, changeset} = Tax.create_repatriation_plan(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:source_jurisdiction]
      assert errors[:target_jurisdiction]
      assert errors[:amount]
      assert errors[:mechanism]
    end

    test "create_repatriation_plan/1 validates mechanism" do
      company = company_fixture()
      attrs = %{company_id: company.id, source_jurisdiction: "IE", target_jurisdiction: "US", amount: 100.0, mechanism: "invalid"}
      assert {:error, changeset} = Tax.create_repatriation_plan(attrs)
      assert "is invalid" in errors_on(changeset)[:mechanism]
    end

    test "create_repatriation_plan/1 validates status" do
      company = company_fixture()
      attrs = %{company_id: company.id, source_jurisdiction: "IE", target_jurisdiction: "US", amount: 100.0, mechanism: "dividend", status: "bogus"}
      assert {:error, changeset} = Tax.create_repatriation_plan(attrs)
      assert "is invalid" in errors_on(changeset)[:status]
    end

    test "create_repatriation_plan/1 accepts all valid mechanisms" do
      company = company_fixture()

      for mechanism <- ~w(dividend loan_repayment management_fee royalty liquidation) do
        attrs = %{
          company_id: company.id,
          source_jurisdiction: "IE",
          target_jurisdiction: "US",
          amount: 1000.0,
          mechanism: mechanism,
          withholding_tax_rate: 0.05
        }

        assert {:ok, _} = Tax.create_repatriation_plan(attrs)
      end
    end

    test "update_repatriation_plan/2 updates the plan and recalculates" do
      plan = repatriation_plan_fixture()
      assert {:ok, updated} = Tax.update_repatriation_plan(plan, %{amount: 200000.0, withholding_tax_rate: 0.10})

      # 200000 * 0.10 = 20000
      assert Money.equal?(updated.withholding_tax_amount, Decimal.new(20000))
      # 200000 - 20000 = 180000
      assert Money.equal?(updated.net_amount, Decimal.new(180000))
    end

    test "update_repatriation_plan/2 fails with invalid data" do
      plan = repatriation_plan_fixture()
      assert {:error, _} = Tax.update_repatriation_plan(plan, %{mechanism: "bogus"})
    end

    test "delete_repatriation_plan/1 removes the plan" do
      plan = repatriation_plan_fixture()
      assert {:ok, _} = Tax.delete_repatriation_plan(plan)
      assert_raise Ecto.NoResultsError, fn -> Tax.get_repatriation_plan!(plan.id) end
    end
  end

  # ── Calculate Repatriation ─────────────────────────────

  describe "calculate_repatriation/1" do
    test "calculates withholding tax amount and net amount" do
      result = Tax.calculate_repatriation(%{amount: 100000, withholding_tax_rate: 0.15})

      assert Money.equal?(result.withholding_tax_amount, Decimal.new(15000))
      assert Money.equal?(result.net_amount, Decimal.new(85000))
      assert Money.equal?(result.effective_tax_rate, Decimal.from_float(0.15))
    end

    test "handles zero withholding rate" do
      result = Tax.calculate_repatriation(%{amount: 50000, withholding_tax_rate: 0})

      assert Decimal.equal?(result.withholding_tax_amount, Decimal.new(0))
      assert Money.equal?(result.net_amount, Decimal.new(50000))
    end

    test "handles zero amount" do
      result = Tax.calculate_repatriation(%{amount: 0, withholding_tax_rate: 0.15})

      assert Decimal.equal?(result.withholding_tax_amount, Decimal.new(0))
      assert Decimal.equal?(result.net_amount, Decimal.new(0))
      assert Decimal.equal?(result.effective_tax_rate, Decimal.new(0))
    end

    test "accepts string keys" do
      result = Tax.calculate_repatriation(%{"amount" => 200000, "withholding_tax_rate" => 0.25})

      assert Money.equal?(result.withholding_tax_amount, Decimal.new(50000))
      assert Money.equal?(result.net_amount, Decimal.new(150000))
    end

    test "handles nil values gracefully" do
      result = Tax.calculate_repatriation(%{})

      assert Decimal.equal?(result.amount, Decimal.new(0))
      assert Decimal.equal?(result.net_amount, Decimal.new(0))
    end
  end

  # ── PubSub ─────────────────────────────────────────────

  describe "subscribe/0" do
    test "subscribes to tax topic" do
      assert :ok = Tax.subscribe()
    end
  end
end
