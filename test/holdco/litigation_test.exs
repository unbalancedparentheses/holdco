defmodule Holdco.LitigationTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "litigations" do
    test "list_litigations/0 returns all litigations" do
      lit = litigation_fixture()
      results = Compliance.list_litigations()
      assert Enum.any?(results, &(&1.id == lit.id))
    end

    test "list_litigations/1 filters by company" do
      company = company_fixture()
      lit = litigation_fixture(%{company: company})
      _other = litigation_fixture()
      results = Compliance.list_litigations(company.id)
      assert Enum.all?(results, &(&1.company_id == company.id))
      assert Enum.any?(results, &(&1.id == lit.id))
    end

    test "get_litigation!/1 returns the litigation" do
      lit = litigation_fixture()
      found = Compliance.get_litigation!(lit.id)
      assert found.id == lit.id
      assert found.company != nil
    end

    test "get_litigation!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_litigation!(0)
      end
    end

    test "create_litigation/1 with valid data" do
      company = company_fixture()

      assert {:ok, lit} =
               Compliance.create_litigation(%{
                 company_id: company.id,
                 case_name: "Smith v. Corp",
                 case_number: "CV-2024-999",
                 case_type: "civil",
                 party_role: "defendant",
                 opposing_party: "Smith LLC",
                 filing_date: "2024-04-01",
                 estimated_exposure: "1000000.00"
               })

      assert lit.case_name == "Smith v. Corp"
      assert lit.case_type == "civil"
      assert lit.party_role == "defendant"
    end

    test "create_litigation/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_litigation(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:case_name]
    end

    test "create_litigation/1 validates case_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_litigation(%{
                 company_id: company.id,
                 case_name: "Test",
                 case_type: "invalid",
                 party_role: "defendant"
               })

      assert errors_on(changeset)[:case_type]
    end

    test "create_litigation/1 validates party_role" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_litigation(%{
                 company_id: company.id,
                 case_name: "Test",
                 case_type: "civil",
                 party_role: "invalid"
               })

      assert errors_on(changeset)[:party_role]
    end

    test "create_litigation/1 with all case types" do
      company = company_fixture()

      for ct <- ~w(civil criminal regulatory arbitration mediation administrative) do
        assert {:ok, lit} =
                 Compliance.create_litigation(%{
                   company_id: company.id,
                   case_name: "Case #{ct}",
                   case_type: ct,
                   party_role: "defendant"
                 })

        assert lit.case_type == ct
      end
    end

    test "create_litigation/1 with all party roles" do
      company = company_fixture()

      for pr <- ~w(plaintiff defendant respondent petitioner) do
        assert {:ok, lit} =
                 Compliance.create_litigation(%{
                   company_id: company.id,
                   case_name: "Role #{pr}",
                   case_type: "civil",
                   party_role: pr
                 })

        assert lit.party_role == pr
      end
    end

    test "update_litigation/2 updates attributes" do
      lit = litigation_fixture()

      assert {:ok, updated} =
               Compliance.update_litigation(lit, %{status: "settled", actual_outcome_amount: "250000.00"})

      assert updated.status == "settled"
      assert Decimal.equal?(updated.actual_outcome_amount, Decimal.new("250000.00"))
    end

    test "delete_litigation/1 deletes the litigation" do
      lit = litigation_fixture()
      assert {:ok, _} = Compliance.delete_litigation(lit)
      assert_raise Ecto.NoResultsError, fn -> Compliance.get_litigation!(lit.id) end
    end
  end

  describe "active_litigation/1" do
    test "returns only active litigation" do
      company = company_fixture()
      active = litigation_fixture(%{company: company, status: "active"})
      _closed = litigation_fixture(%{company: company, status: "closed"})
      _dismissed = litigation_fixture(%{company: company, status: "dismissed"})

      results = Compliance.active_litigation(company.id)
      assert Enum.any?(results, &(&1.id == active.id))
      refute Enum.any?(results, &(&1.status in ["closed", "dismissed"]))
    end
  end

  describe "litigation_exposure/1" do
    test "returns total estimated exposure for active cases" do
      company = company_fixture()
      litigation_fixture(%{company: company, status: "active", estimated_exposure: "500000"})
      litigation_fixture(%{company: company, status: "discovery", estimated_exposure: "300000"})
      litigation_fixture(%{company: company, status: "closed", estimated_exposure: "100000"})

      exposure = Compliance.litigation_exposure(company.id)
      assert Decimal.equal?(exposure, Decimal.new("800000"))
    end

    test "returns zero when no active litigation" do
      company = company_fixture()
      assert Decimal.equal?(Compliance.litigation_exposure(company.id), Decimal.new(0))
    end
  end
end
