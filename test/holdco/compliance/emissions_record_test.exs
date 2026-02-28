defmodule Holdco.Compliance.EmissionsRecordTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "emissions_records CRUD" do
    test "list_emissions_records/0 returns all records" do
      record = emissions_record_fixture()
      assert Enum.any?(Compliance.list_emissions_records(), &(&1.id == record.id))
    end

    test "list_emissions_records/1 filters by company_id" do
      company = company_fixture()
      record = emissions_record_fixture(%{company: company})
      other = emissions_record_fixture()

      results = Compliance.list_emissions_records(company.id)
      assert Enum.any?(results, &(&1.id == record.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_emissions_record!/1 returns record with preloads" do
      record = emissions_record_fixture()
      fetched = Compliance.get_emissions_record!(record.id)
      assert fetched.id == record.id
      assert fetched.company != nil
    end

    test "get_emissions_record!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_emissions_record!(0)
      end
    end

    test "create_emissions_record/1 with valid data" do
      company = company_fixture()

      assert {:ok, record} =
               Compliance.create_emissions_record(%{
                 company_id: company.id,
                 reporting_year: 2025,
                 scope: "scope_1",
                 category: "energy",
                 source_description: "Natural gas boiler",
                 quantity: "500.0",
                 unit: "tonnes_co2e",
                 emission_factor: "2.1",
                 co2_equivalent: "1050.0",
                 methodology: "GHG Protocol",
                 verification_status: "self_assessed"
               })

      assert record.scope == "scope_1"
      assert record.category == "energy"
      assert Decimal.equal?(record.co2_equivalent, Decimal.new("1050.0"))
    end

    test "create_emissions_record/1 with all scopes" do
      company = company_fixture()

      for scope <- ~w(scope_1 scope_2 scope_3) do
        assert {:ok, record} =
                 Compliance.create_emissions_record(%{
                   company_id: company.id,
                   reporting_year: 2025,
                   scope: scope,
                   category: "energy"
                 })

        assert record.scope == scope
      end
    end

    test "create_emissions_record/1 with all categories" do
      company = company_fixture()

      for cat <- ~w(energy transport waste supply_chain other) do
        assert {:ok, record} =
                 Compliance.create_emissions_record(%{
                   company_id: company.id,
                   reporting_year: 2025,
                   scope: "scope_1",
                   category: cat
                 })

        assert record.category == cat
      end
    end

    test "create_emissions_record/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_emissions_record(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:reporting_year]
    end

    test "create_emissions_record/1 fails with invalid scope" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_emissions_record(%{
                 company_id: company.id,
                 reporting_year: 2025,
                 scope: "scope_4",
                 category: "energy"
               })

      assert errors_on(changeset)[:scope]
    end

    test "create_emissions_record/1 fails with invalid category" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_emissions_record(%{
                 company_id: company.id,
                 reporting_year: 2025,
                 scope: "scope_1",
                 category: "invalid"
               })

      assert errors_on(changeset)[:category]
    end

    test "update_emissions_record/2 with valid data" do
      record = emissions_record_fixture()

      assert {:ok, updated} =
               Compliance.update_emissions_record(record, %{
                 co2_equivalent: "2000.0",
                 verification_status: "third_party_verified"
               })

      assert Decimal.equal?(updated.co2_equivalent, Decimal.new("2000.0"))
      assert updated.verification_status == "third_party_verified"
    end

    test "delete_emissions_record/1 removes the record" do
      record = emissions_record_fixture()
      assert {:ok, _} = Compliance.delete_emissions_record(record)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_emissions_record!(record.id)
      end
    end
  end

  describe "emissions_by_scope/1" do
    test "returns emissions grouped by scope" do
      company = company_fixture()
      emissions_record_fixture(%{company: company, scope: "scope_1", co2_equivalent: "100.0"})
      emissions_record_fixture(%{company: company, scope: "scope_1", co2_equivalent: "200.0"})
      emissions_record_fixture(%{company: company, scope: "scope_2", co2_equivalent: "50.0"})

      result = Compliance.emissions_by_scope(company.id)
      scope_1 = Enum.find(result, &(&1.scope == "scope_1"))
      assert scope_1.count == 2
      assert Decimal.equal?(scope_1.total_co2e, Decimal.new("300.0"))
    end
  end

  describe "total_emissions/2" do
    test "returns total emissions for a company and year" do
      company = company_fixture()
      emissions_record_fixture(%{company: company, reporting_year: 2025, co2_equivalent: "100.0"})
      emissions_record_fixture(%{company: company, reporting_year: 2025, co2_equivalent: "200.0"})
      emissions_record_fixture(%{company: company, reporting_year: 2024, co2_equivalent: "50.0"})

      result = Compliance.total_emissions(company.id, 2025)
      assert result.count == 2
      assert Decimal.equal?(result.total_co2e, Decimal.new("300.0"))
    end

    test "returns nil total when no records exist" do
      company = company_fixture()
      result = Compliance.total_emissions(company.id, 2025)
      assert result.count == 0
      assert result.total_co2e == nil
    end
  end
end
