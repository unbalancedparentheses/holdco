defmodule Holdco.InsuranceClaimTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "insurance_claims" do
    test "list_insurance_claims/0 returns all claims" do
      ic = insurance_claim_fixture()
      results = Compliance.list_insurance_claims()
      assert Enum.any?(results, &(&1.id == ic.id))
    end

    test "list_insurance_claims/1 filters by company" do
      company = company_fixture()
      ic = insurance_claim_fixture(%{company: company})
      _other = insurance_claim_fixture()
      results = Compliance.list_insurance_claims(company.id)
      assert Enum.all?(results, &(&1.company_id == company.id))
      assert Enum.any?(results, &(&1.id == ic.id))
    end

    test "list_insurance_claims/1 returns empty for company with no claims" do
      company = company_fixture()
      assert Compliance.list_insurance_claims(company.id) == []
    end

    test "get_insurance_claim!/1 returns the claim with preloads" do
      ic = insurance_claim_fixture()
      found = Compliance.get_insurance_claim!(ic.id)
      assert found.id == ic.id
      assert found.company != nil
    end

    test "get_insurance_claim!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_insurance_claim!(0)
      end
    end

    test "create_insurance_claim/1 with valid data" do
      company = company_fixture()

      assert {:ok, ic} =
               Compliance.create_insurance_claim(%{
                 company_id: company.id,
                 claim_number: "CLM-TEST-1",
                 claim_type: "liability",
                 incident_date: "2024-05-01",
                 filing_date: "2024-05-15",
                 claimed_amount: "75000.00",
                 status: "under_review"
               })

      assert ic.claim_number == "CLM-TEST-1"
      assert ic.claim_type == "liability"
      assert ic.status == "under_review"
    end

    test "create_insurance_claim/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_insurance_claim(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:claim_number]
    end

    test "create_insurance_claim/1 validates claim_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_insurance_claim(%{
                 company_id: company.id,
                 claim_number: "CLM-BAD",
                 claim_type: "invalid_type"
               })

      assert errors_on(changeset)[:claim_type]
    end

    test "create_insurance_claim/1 validates status" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_insurance_claim(%{
                 company_id: company.id,
                 claim_number: "CLM-BAD2",
                 claim_type: "property",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "create_insurance_claim/1 validates unique claim_number" do
      insurance_claim_fixture(%{claim_number: "UNIQUE-1"})

      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_insurance_claim(%{
                 company_id: company.id,
                 claim_number: "UNIQUE-1",
                 claim_type: "property"
               })

      assert errors_on(changeset)[:claim_number]
    end

    test "create_insurance_claim/1 with all claim types" do
      company = company_fixture()

      for {ct, i} <- Enum.with_index(~w(property liability professional cyber directors_officers workers_comp other)) do
        assert {:ok, ic} =
                 Compliance.create_insurance_claim(%{
                   company_id: company.id,
                   claim_number: "CT-#{i}-#{System.unique_integer([:positive])}",
                   claim_type: ct
                 })

        assert ic.claim_type == ct
      end
    end

    test "update_insurance_claim/2 updates attributes" do
      ic = insurance_claim_fixture()

      assert {:ok, updated} =
               Compliance.update_insurance_claim(ic, %{status: "settled", settled_amount: "30000.00"})

      assert updated.status == "settled"
      assert Decimal.equal?(updated.settled_amount, Decimal.new("30000.00"))
    end

    test "delete_insurance_claim/1 deletes the claim" do
      ic = insurance_claim_fixture()
      assert {:ok, _} = Compliance.delete_insurance_claim(ic)
      assert_raise Ecto.NoResultsError, fn -> Compliance.get_insurance_claim!(ic.id) end
    end
  end

  describe "open_claims/1" do
    test "returns only open claims" do
      company = company_fixture()
      open = insurance_claim_fixture(%{company: company, status: "filed"})
      _closed = insurance_claim_fixture(%{company: company, status: "closed"})
      _denied = insurance_claim_fixture(%{company: company, status: "denied"})

      results = Compliance.open_claims(company.id)
      assert Enum.any?(results, &(&1.id == open.id))
      refute Enum.any?(results, &(&1.status == "closed"))
      refute Enum.any?(results, &(&1.status == "denied"))
    end
  end

  describe "claims_summary/1" do
    test "returns summary with by_status and by_type" do
      company = company_fixture()
      insurance_claim_fixture(%{company: company, claim_type: "property", claimed_amount: "10000"})
      insurance_claim_fixture(%{company: company, claim_type: "liability", claimed_amount: "20000"})

      summary = Compliance.claims_summary(company.id)
      assert is_list(summary.by_status)
      assert is_list(summary.by_type)
      assert %Decimal{} = summary.total_claimed
      assert Decimal.equal?(summary.total_claimed, Decimal.new("30000"))
    end
  end
end
