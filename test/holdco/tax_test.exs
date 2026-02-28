defmodule Holdco.TaxTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Tax

  # ── Tax Provisions CRUD ──────────────────────────────────

  describe "list_tax_provisions/1" do
    test "returns all tax provisions" do
      tp = tax_provision_fixture()
      provisions = Tax.list_tax_provisions()
      assert length(provisions) >= 1
      assert Enum.any?(provisions, &(&1.id == tp.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "TaxCo1"})
      c2 = company_fixture(%{name: "TaxCo2"})
      tp1 = tax_provision_fixture(%{company: c1})
      _tp2 = tax_provision_fixture(%{company: c2})

      provisions = Tax.list_tax_provisions(company_id: c1.id)
      assert length(provisions) == 1
      assert hd(provisions).id == tp1.id
    end

    test "filters by tax_year" do
      company = company_fixture()
      tp1 = tax_provision_fixture(%{company: company, tax_year: 2024})
      _tp2 = tax_provision_fixture(%{company: company, tax_year: 2025})

      provisions = Tax.list_tax_provisions(company_id: company.id, tax_year: 2024)
      assert length(provisions) == 1
      assert hd(provisions).id == tp1.id
    end

    test "filters by jurisdiction" do
      company = company_fixture()
      tp1 = tax_provision_fixture(%{company: company, jurisdiction: "UK"})
      _tp2 = tax_provision_fixture(%{company: company, jurisdiction: "US"})

      provisions = Tax.list_tax_provisions(company_id: company.id, jurisdiction: "UK")
      assert length(provisions) == 1
      assert hd(provisions).id == tp1.id
    end

    test "returns empty list when no provisions" do
      company = company_fixture()
      assert Tax.list_tax_provisions(company_id: company.id) == []
    end
  end

  describe "get_tax_provision!/1" do
    test "returns the tax provision with given id" do
      tp = tax_provision_fixture()
      found = Tax.get_tax_provision!(tp.id)
      assert found.id == tp.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Tax.get_tax_provision!(0)
      end
    end
  end

  describe "create_tax_provision/1" do
    test "creates a tax provision with valid attrs" do
      company = company_fixture()

      assert {:ok, tp} =
               Tax.create_tax_provision(%{
                 company_id: company.id,
                 tax_year: 2025,
                 jurisdiction: "US",
                 provision_type: "current",
                 tax_type: "income",
                 taxable_income: 500_000.0,
                 tax_rate: 21.0,
                 tax_amount: 105_000.0
               })

      assert tp.jurisdiction == "US"
      assert tp.provision_type == "current"
      assert Decimal.equal?(tp.tax_rate, Decimal.from_float(21.0))
    end

    test "validates required fields" do
      assert {:error, changeset} = Tax.create_tax_provision(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:tax_year]
      assert errors[:jurisdiction]
      assert errors[:provision_type]
    end

    test "validates provision_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Tax.create_tax_provision(%{
                 company_id: company.id,
                 tax_year: 2025,
                 jurisdiction: "US",
                 provision_type: "invalid"
               })

      assert %{provision_type: _} = errors_on(changeset)
    end

    test "validates status inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Tax.create_tax_provision(%{
                 company_id: company.id,
                 tax_year: 2025,
                 jurisdiction: "US",
                 provision_type: "current",
                 status: "nonexistent"
               })

      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "update_tax_provision/2" do
    test "updates a tax provision" do
      tp = tax_provision_fixture(%{status: "estimated"})
      assert {:ok, updated} = Tax.update_tax_provision(tp, %{status: "filed"})
      assert updated.status == "filed"
    end
  end

  describe "delete_tax_provision/1" do
    test "deletes the tax provision" do
      tp = tax_provision_fixture()
      assert {:ok, _} = Tax.delete_tax_provision(tp)

      assert_raise Ecto.NoResultsError, fn ->
        Tax.get_tax_provision!(tp.id)
      end
    end
  end

  # ── Calculate Provision ──────────────────────────────────

  describe "calculate_provision/4" do
    test "calculates provision from financials" do
      company = company_fixture()

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q1",
          revenue: 300_000.0,
          expenses: 100_000.0
        })

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2025-Q2",
          revenue: 200_000.0,
          expenses: 50_000.0
        })

      {:ok, result} = Tax.calculate_provision(company.id, 2025, "US", 21.0)

      # Total revenue = 500k, total expenses = 150k, taxable income = 350k
      # Tax amount = 350k * 0.21 = 73,500
      assert Decimal.equal?(result.taxable_income, Decimal.new("350000.00"))
      assert Decimal.equal?(result.tax_amount, Decimal.new("73500.00"))
      assert result.jurisdiction == "US"
    end

    test "returns zero when no financials match the year" do
      company = company_fixture()

      {:ok, _} =
        Holdco.Finance.create_financial(%{
          company_id: company.id,
          period: "2024-Q1",
          revenue: 100_000.0,
          expenses: 50_000.0
        })

      {:ok, result} = Tax.calculate_provision(company.id, 2025, "UK", 25.0)

      assert Decimal.equal?(result.taxable_income, Decimal.new("0.00"))
      assert Decimal.equal?(result.tax_amount, Decimal.new("0.00"))
    end
  end

  # ── Deferred Taxes CRUD ──────────────────────────────────

  describe "list_deferred_taxes/1" do
    test "returns all deferred taxes" do
      dt = deferred_tax_fixture()
      taxes = Tax.list_deferred_taxes()
      assert length(taxes) >= 1
      assert Enum.any?(taxes, &(&1.id == dt.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "DefCo1"})
      c2 = company_fixture(%{name: "DefCo2"})
      dt1 = deferred_tax_fixture(%{company: c1})
      _dt2 = deferred_tax_fixture(%{company: c2})

      taxes = Tax.list_deferred_taxes(company_id: c1.id)
      assert length(taxes) == 1
      assert hd(taxes).id == dt1.id
    end

    test "filters by deferred_type" do
      company = company_fixture()
      dt1 = deferred_tax_fixture(%{company: company, deferred_type: "asset", description: "DTA"})
      _dt2 = deferred_tax_fixture(%{company: company, deferred_type: "liability", description: "DTL"})

      taxes = Tax.list_deferred_taxes(company_id: company.id, deferred_type: "asset")
      assert length(taxes) == 1
      assert hd(taxes).id == dt1.id
    end

    test "returns empty list when no deferred taxes" do
      company = company_fixture()
      assert Tax.list_deferred_taxes(company_id: company.id) == []
    end
  end

  describe "get_deferred_tax!/1" do
    test "returns the deferred tax with given id" do
      dt = deferred_tax_fixture()
      found = Tax.get_deferred_tax!(dt.id)
      assert found.id == dt.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Tax.get_deferred_tax!(0)
      end
    end
  end

  describe "create_deferred_tax/1" do
    test "creates a deferred tax with valid attrs" do
      company = company_fixture()

      assert {:ok, dt} =
               Tax.create_deferred_tax(%{
                 company_id: company.id,
                 tax_year: 2025,
                 description: "Depreciation timing diff",
                 deferred_type: "liability",
                 source: "depreciation",
                 book_basis: 50_000.0,
                 tax_basis: 40_000.0,
                 temporary_difference: 10_000.0,
                 tax_rate: 21.0,
                 deferred_amount: 2_100.0
               })

      assert dt.description == "Depreciation timing diff"
      assert dt.deferred_type == "liability"
    end

    test "validates required fields" do
      assert {:error, changeset} = Tax.create_deferred_tax(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:tax_year]
      assert errors[:description]
      assert errors[:deferred_type]
    end

    test "validates deferred_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Tax.create_deferred_tax(%{
                 company_id: company.id,
                 tax_year: 2025,
                 description: "Bad type",
                 deferred_type: "invalid"
               })

      assert %{deferred_type: _} = errors_on(changeset)
    end
  end

  describe "update_deferred_tax/2" do
    test "updates a deferred tax" do
      dt = deferred_tax_fixture()
      assert {:ok, updated} = Tax.update_deferred_tax(dt, %{description: "Updated desc"})
      assert updated.description == "Updated desc"
    end
  end

  describe "delete_deferred_tax/1" do
    test "deletes the deferred tax" do
      dt = deferred_tax_fixture()
      assert {:ok, _} = Tax.delete_deferred_tax(dt)

      assert_raise Ecto.NoResultsError, fn ->
        Tax.get_deferred_tax!(dt.id)
      end
    end
  end

  # ── Calculate Deferred Tax ───────────────────────────────

  describe "calculate_deferred_tax/3" do
    test "calculates deferred tax liability when book > tax basis" do
      result = Tax.calculate_deferred_tax(100_000, 80_000, 21)

      assert Decimal.compare(result.temporary_difference, Decimal.new(0)) == :gt
      assert result.deferred_type == "liability"
      # 20,000 * 0.21 = 4,200
      assert Decimal.equal?(result.deferred_amount, Decimal.new("4200"))
    end

    test "calculates deferred tax asset when tax > book basis" do
      result = Tax.calculate_deferred_tax(50_000, 80_000, 25)

      assert Decimal.compare(result.temporary_difference, Decimal.new(0)) == :lt
      assert result.deferred_type == "asset"
      # |(-30,000) * 0.25| = 7,500
      assert Decimal.equal?(result.deferred_amount, Decimal.new("7500"))
    end

    test "returns asset type with zero difference when book equals tax basis" do
      result = Tax.calculate_deferred_tax(100_000, 100_000, 21)

      assert Decimal.equal?(result.temporary_difference, Decimal.new(0))
      assert Decimal.equal?(result.deferred_amount, Decimal.new(0))
      assert result.deferred_type == "asset"
    end
  end

  # ── Tax Summary ──────────────────────────────────────────

  describe "tax_summary/2" do
    test "aggregates tax data for a company and year" do
      company = company_fixture()

      # Create current provisions
      tax_provision_fixture(%{
        company: company,
        tax_year: 2025,
        provision_type: "current",
        taxable_income: 200_000.0,
        tax_rate: 21.0,
        tax_amount: 42_000.0
      })

      tax_provision_fixture(%{
        company: company,
        tax_year: 2025,
        provision_type: "current",
        jurisdiction: "UK",
        taxable_income: 100_000.0,
        tax_rate: 25.0,
        tax_amount: 25_000.0
      })

      # Create deferred taxes
      deferred_tax_fixture(%{
        company: company,
        tax_year: 2025,
        deferred_type: "liability",
        deferred_amount: 5_000.0,
        description: "DTL 1"
      })

      deferred_tax_fixture(%{
        company: company,
        tax_year: 2025,
        deferred_type: "asset",
        deferred_amount: 2_000.0,
        description: "DTA 1"
      })

      summary = Tax.tax_summary(company.id, 2025)

      # Total current = 42000 + 25000 = 67000
      assert Decimal.equal?(summary.total_current_provision, Decimal.new("67000.00"))
      assert Decimal.equal?(summary.total_deferred_assets, Decimal.new("2000.00"))
      assert Decimal.equal?(summary.total_deferred_liabilities, Decimal.new("5000.00"))

      # Total tax = 67000 + (5000 - 2000) = 70000
      assert Decimal.equal?(summary.total_tax_expense, Decimal.new("70000.00"))

      # Effective rate = 70000 / 300000 * 100 = 23.33
      assert Decimal.equal?(summary.effective_tax_rate, Decimal.new("23.33"))
    end

    test "returns zeros when no data exists" do
      company = company_fixture()
      summary = Tax.tax_summary(company.id, 2025)

      assert Decimal.equal?(summary.total_current_provision, Decimal.new("0.00"))
      assert Decimal.equal?(summary.total_deferred_assets, Decimal.new("0.00"))
      assert Decimal.equal?(summary.total_deferred_liabilities, Decimal.new("0.00"))
      assert Decimal.equal?(summary.total_tax_expense, Decimal.new("0.00"))
      assert Decimal.equal?(summary.effective_tax_rate, Decimal.new(0))
    end
  end
end
