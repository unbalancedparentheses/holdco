defmodule Holdco.Compliance.RegulatoryCapitalTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "regulatory_capital CRUD" do
    test "list_regulatory_capital_records/0 returns all records" do
      record = regulatory_capital_fixture()
      assert Enum.any?(Compliance.list_regulatory_capital_records(), &(&1.id == record.id))
    end

    test "list_regulatory_capital_records/1 filters by company_id" do
      company = company_fixture()
      record = regulatory_capital_fixture(%{company: company})
      other = regulatory_capital_fixture()

      results = Compliance.list_regulatory_capital_records(company.id)
      assert Enum.any?(results, &(&1.id == record.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_regulatory_capital!/1 returns record with preloads" do
      record = regulatory_capital_fixture()
      fetched = Compliance.get_regulatory_capital!(record.id)
      assert fetched.id == record.id
      assert fetched.company != nil
    end

    test "get_regulatory_capital!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_regulatory_capital!(0)
      end
    end

    test "create_regulatory_capital/1 with valid data" do
      company = company_fixture()

      assert {:ok, record} =
               Compliance.create_regulatory_capital(%{
                 company_id: company.id,
                 reporting_date: "2025-12-31",
                 framework: "basel_iii",
                 tier1_capital: "500000.00",
                 tier2_capital: "100000.00",
                 total_capital: "600000.00",
                 risk_weighted_assets: "4000000.00",
                 capital_ratio: "15.0",
                 minimum_required_ratio: "8.0",
                 buffer_required: "2.5",
                 surplus_or_deficit: "280000.00",
                 currency: "USD",
                 status: "compliant"
               })

      assert record.framework == "basel_iii"
      assert Decimal.equal?(record.capital_ratio, Decimal.new("15.0"))
      assert record.status == "compliant"
    end

    test "create_regulatory_capital/1 with all frameworks" do
      company = company_fixture()

      for framework <- ~w(basel_iii solvency_ii mifid_ii dodd_frank custom) do
        assert {:ok, record} =
                 Compliance.create_regulatory_capital(%{
                   company_id: company.id,
                   reporting_date: "2025-12-31",
                   framework: framework
                 })

        assert record.framework == framework
      end
    end

    test "create_regulatory_capital/1 with all statuses" do
      company = company_fixture()

      for status <- ~w(compliant warning breach) do
        assert {:ok, record} =
                 Compliance.create_regulatory_capital(%{
                   company_id: company.id,
                   reporting_date: "2025-12-31",
                   framework: "basel_iii",
                   status: status
                 })

        assert record.status == status
      end
    end

    test "create_regulatory_capital/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_regulatory_capital(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:reporting_date]
    end

    test "create_regulatory_capital/1 fails with invalid framework" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_regulatory_capital(%{
                 company_id: company.id,
                 reporting_date: "2025-12-31",
                 framework: "invalid"
               })

      assert errors_on(changeset)[:framework]
    end

    test "update_regulatory_capital/2 with valid data" do
      record = regulatory_capital_fixture()

      assert {:ok, updated} =
               Compliance.update_regulatory_capital(record, %{
                 capital_ratio: "12.0",
                 status: "warning",
                 notes: "Approaching minimum threshold"
               })

      assert Decimal.equal?(updated.capital_ratio, Decimal.new("12.0"))
      assert updated.status == "warning"
      assert updated.notes == "Approaching minimum threshold"
    end

    test "delete_regulatory_capital/1 removes the record" do
      record = regulatory_capital_fixture()
      assert {:ok, _} = Compliance.delete_regulatory_capital(record)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_regulatory_capital!(record.id)
      end
    end
  end

  describe "latest_capital_position/1" do
    test "returns the most recent capital position" do
      company = company_fixture()
      _old = regulatory_capital_fixture(%{company: company, reporting_date: "2024-06-30"})
      new = regulatory_capital_fixture(%{company: company, reporting_date: "2025-12-31"})

      result = Compliance.latest_capital_position(company.id)
      assert result.id == new.id
    end

    test "returns nil when no records exist" do
      company = company_fixture()
      assert Compliance.latest_capital_position(company.id) == nil
    end
  end

  describe "capital_trend/1" do
    test "returns capital ratios ordered by reporting date" do
      company = company_fixture()
      regulatory_capital_fixture(%{company: company, reporting_date: "2024-06-30", capital_ratio: "14.0"})
      regulatory_capital_fixture(%{company: company, reporting_date: "2024-12-31", capital_ratio: "15.0"})
      regulatory_capital_fixture(%{company: company, reporting_date: "2025-06-30", capital_ratio: "13.5"})

      trend = Compliance.capital_trend(company.id)
      assert length(trend) == 3
      assert Decimal.equal?(Enum.at(trend, 0).capital_ratio, Decimal.new("14.0"))
      assert Decimal.equal?(Enum.at(trend, 2).capital_ratio, Decimal.new("13.5"))
    end
  end
end
