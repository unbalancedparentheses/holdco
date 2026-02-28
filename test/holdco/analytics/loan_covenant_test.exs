defmodule Holdco.Analytics.LoanCovenantTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "Loan Covenants CRUD" do
    test "create_loan_covenant/1 with valid attrs" do
      company = company_fixture()

      assert {:ok, covenant} =
               Analytics.create_loan_covenant(%{
                 company_id: company.id,
                 name: "Max Leverage Ratio",
                 covenant_type: "financial",
                 metric: "max_leverage",
                 threshold: 3.0,
                 comparison: "below",
                 status: "compliant",
                 measurement_frequency: "quarterly"
               })

      assert covenant.name == "Max Leverage Ratio"
      assert covenant.covenant_type == "financial"
      assert covenant.comparison == "below"
    end

    test "list_loan_covenants/0 returns all covenants" do
      cov = loan_covenant_fixture(%{name: "Test Covenant"})
      covenants = Analytics.list_loan_covenants()
      assert length(covenants) >= 1
      assert Enum.any?(covenants, &(&1.id == cov.id))
    end

    test "list_loan_covenants/1 filters by company_id" do
      c1 = company_fixture(%{name: "CovCo1"})
      c2 = company_fixture(%{name: "CovCo2"})
      cov1 = loan_covenant_fixture(%{company: c1, name: "Cov A"})
      _cov2 = loan_covenant_fixture(%{company: c2, name: "Cov B"})

      covenants = Analytics.list_loan_covenants(c1.id)
      assert length(covenants) == 1
      assert hd(covenants).id == cov1.id
    end

    test "get_loan_covenant!/1 returns the covenant" do
      cov = loan_covenant_fixture(%{name: "Get Covenant"})
      found = Analytics.get_loan_covenant!(cov.id)
      assert found.id == cov.id
      assert found.name == "Get Covenant"
    end

    test "update_loan_covenant/2 updates successfully" do
      cov = loan_covenant_fixture(%{name: "Old Covenant"})
      assert {:ok, updated} = Analytics.update_loan_covenant(cov, %{name: "New Covenant"})
      assert updated.name == "New Covenant"
    end

    test "delete_loan_covenant/1 deletes the covenant" do
      cov = loan_covenant_fixture()
      assert {:ok, _} = Analytics.delete_loan_covenant(cov)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_loan_covenant!(cov.id)
      end
    end
  end

  describe "validations" do
    test "validates required name and covenant_type" do
      assert {:error, changeset} = Analytics.create_loan_covenant(%{})
      errors = errors_on(changeset)
      assert %{name: ["can't be blank"]} = errors
      assert %{covenant_type: ["can't be blank"]} = errors
    end

    test "validates covenant_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_loan_covenant(%{
                 name: "Test",
                 covenant_type: "invalid_type"
               })

      assert %{covenant_type: _} = errors_on(changeset)
    end

    test "validates comparison inclusion" do
      assert {:error, changeset} =
               Analytics.create_loan_covenant(%{
                 name: "Test",
                 covenant_type: "financial",
                 comparison: "invalid"
               })

      assert %{comparison: _} = errors_on(changeset)
    end

    test "validates status inclusion" do
      assert {:error, changeset} =
               Analytics.create_loan_covenant(%{
                 name: "Test",
                 covenant_type: "financial",
                 status: "invalid"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "validates measurement_frequency inclusion" do
      assert {:error, changeset} =
               Analytics.create_loan_covenant(%{
                 name: "Test",
                 covenant_type: "financial",
                 measurement_frequency: "invalid"
               })

      assert %{measurement_frequency: _} = errors_on(changeset)
    end
  end

  describe "check_covenant_compliance/1" do
    test "min_cash compliant when cash is above threshold" do
      company = company_fixture()
      # Create a bank account with sufficient balance
      bank_account_fixture(%{company: company, balance: 500_000.0})

      cov = loan_covenant_fixture(%{
        company: company,
        name: "Minimum Cash",
        covenant_type: "financial",
        metric: "min_cash",
        threshold: 100_000.0,
        comparison: "above"
      })

      {status, value} = Analytics.check_covenant_compliance(cov)
      assert status == :compliant
      assert Decimal.compare(value, Decimal.new("100000")) == :gt
    end

    test "min_cash breached when cash is below threshold" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10_000.0})

      cov = loan_covenant_fixture(%{
        company: company,
        name: "Minimum Cash",
        covenant_type: "financial",
        metric: "min_cash",
        threshold: 500_000.0,
        comparison: "above"
      })

      {status, _value} = Analytics.check_covenant_compliance(cov)
      assert status == :breached
    end

    test "compliant with current_value set directly when no metric" do
      cov = loan_covenant_fixture(%{
        name: "Custom Metric",
        covenant_type: "financial",
        metric: "custom",
        threshold: 1.0,
        comparison: "above",
        current_value: 2.0
      })

      {status, value} = Analytics.check_covenant_compliance(cov)
      assert status == :compliant
      assert Decimal.compare(value, Decimal.new("1")) == :gt
    end

    test "debt_to_equity compliance check" do
      company = company_fixture()

      # This test verifies the function runs; actual values depend on journal entries
      cov = loan_covenant_fixture(%{
        company: company,
        name: "Debt to Equity",
        covenant_type: "financial",
        metric: "debt_to_equity",
        threshold: 3.0,
        comparison: "below"
      })

      # Should not raise - returns compliant with nil if no data
      {status, _value} = Analytics.check_covenant_compliance(cov)
      assert status in [:compliant, :warning, :breached]
    end
  end

  describe "check_all_covenants/1" do
    test "updates statuses for all covenants" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 1_000_000.0})

      cov = loan_covenant_fixture(%{
        company: company,
        name: "Cash Check",
        covenant_type: "financial",
        metric: "min_cash",
        threshold: 100_000.0,
        comparison: "above",
        status: "warning"
      })

      results = Analytics.check_all_covenants(company.id)
      assert length(results) >= 1

      {updated_cov, status} = Enum.find(results, fn {c, _s} -> c.id == cov.id end)
      assert status == :compliant
      assert updated_cov.status == "compliant"
      assert updated_cov.last_measured_at != nil
    end
  end

  describe "covenant with liability association" do
    test "covenant can be associated with a liability" do
      company = company_fixture()
      liability = liability_fixture(%{company: company})

      assert {:ok, covenant} =
               Analytics.create_loan_covenant(%{
                 company_id: company.id,
                 liability_id: liability.id,
                 name: "Linked Covenant",
                 covenant_type: "financial",
                 metric: "max_leverage",
                 threshold: 2.0,
                 comparison: "below"
               })

      found = Analytics.get_loan_covenant!(covenant.id)
      assert found.liability_id == liability.id
      assert found.liability.id == liability.id
    end
  end

  describe "breach tracking" do
    test "breach increments breach_count" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 10.0})

      cov = loan_covenant_fixture(%{
        company: company,
        name: "Cash Floor",
        covenant_type: "financial",
        metric: "min_cash",
        threshold: 1_000_000.0,
        comparison: "above",
        breach_count: 0
      })

      results = Analytics.check_all_covenants(company.id)
      {updated_cov, _status} = Enum.find(results, fn {c, _s} -> c.id == cov.id end)
      assert updated_cov.breach_count == 1
    end
  end
end
