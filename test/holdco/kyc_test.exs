defmodule Holdco.KycTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "kyc_records CRUD" do
    test "create_kyc_record/1 with valid data" do
      company = company_fixture()

      assert {:ok, record} =
               Compliance.create_kyc_record(%{
                 company_id: company.id,
                 entity_name: "John Doe",
                 entity_type: "individual",
                 risk_level: "low"
               })

      assert record.entity_name == "John Doe"
      assert record.entity_type == "individual"
      assert record.risk_level == "low"
      assert record.verification_status == "not_started"
    end

    test "create_kyc_record/1 with invalid data" do
      assert {:error, changeset} = Compliance.create_kyc_record(%{})
      assert errors_on(changeset)[:company_id]
      assert errors_on(changeset)[:entity_name]
    end

    test "create_kyc_record/1 validates entity_type enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_kyc_record(%{
                 company_id: company.id,
                 entity_name: "Test",
                 entity_type: "invalid"
               })

      assert errors_on(changeset)[:entity_type]
    end

    test "create_kyc_record/1 validates risk_level enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_kyc_record(%{
                 company_id: company.id,
                 entity_name: "Test",
                 entity_type: "individual",
                 risk_level: "invalid"
               })

      assert errors_on(changeset)[:risk_level]
    end

    test "create_kyc_record/1 validates verification_status enum" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_kyc_record(%{
                 company_id: company.id,
                 entity_name: "Test",
                 entity_type: "individual",
                 verification_status: "invalid"
               })

      assert errors_on(changeset)[:verification_status]
    end

    test "list_kyc_records/0 returns all records" do
      record = kyc_record_fixture()
      assert Enum.any?(Compliance.list_kyc_records(), &(&1.id == record.id))
    end

    test "list_kyc_records/1 filters by company" do
      company = company_fixture()
      record = kyc_record_fixture(%{company: company})
      _other = kyc_record_fixture()

      results = Compliance.list_kyc_records(company.id)
      assert Enum.any?(results, &(&1.id == record.id))
      assert length(results) == 1
    end

    test "get_kyc_record!/1 returns the record with preloads" do
      record = kyc_record_fixture()
      fetched = Compliance.get_kyc_record!(record.id)
      assert fetched.id == record.id
      assert fetched.company != nil
    end

    test "update_kyc_record/2 updates the record" do
      record = kyc_record_fixture()

      assert {:ok, updated} =
               Compliance.update_kyc_record(record, %{
                 verification_status: "verified",
                 risk_level: "high"
               })

      assert updated.verification_status == "verified"
      assert updated.risk_level == "high"
    end

    test "delete_kyc_record/1 deletes the record" do
      record = kyc_record_fixture()
      assert {:ok, _} = Compliance.delete_kyc_record(record)
      assert_raise Ecto.NoResultsError, fn -> Compliance.get_kyc_record!(record.id) end
    end

    test "create_kyc_record/1 with all optional fields" do
      company = company_fixture()

      assert {:ok, record} =
               Compliance.create_kyc_record(%{
                 company_id: company.id,
                 entity_name: "Corp Inc",
                 entity_type: "corporate",
                 risk_level: "pep",
                 verification_status: "under_review",
                 id_type: "passport",
                 id_number: "AB123456",
                 id_expiry_date: "2030-12-31",
                 country_of_residence: "UK",
                 nationality: "British",
                 pep_status: true,
                 sanctions_checked: true,
                 last_review_date: "2024-01-01",
                 next_review_date: "2025-01-01",
                 reviewer_notes: "High profile entity",
                 documents: ["passport.pdf", "utility_bill.pdf"]
               })

      assert record.id_type == "passport"
      assert record.id_number == "AB123456"
      assert record.pep_status == true
      assert record.sanctions_checked == true
      assert record.documents == ["passport.pdf", "utility_bill.pdf"]
    end
  end

  describe "kyc_due_for_review/0" do
    test "returns records with next_review_date <= today" do
      company = company_fixture()
      past_date = Date.add(Date.utc_today(), -5)
      future_date = Date.add(Date.utc_today(), 30)

      {:ok, due} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Due Entity",
          entity_type: "individual",
          next_review_date: past_date
        })

      {:ok, _not_due} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Not Due Entity",
          entity_type: "individual",
          next_review_date: future_date
        })

      results = Compliance.kyc_due_for_review()
      assert Enum.any?(results, &(&1.id == due.id))
      refute Enum.any?(results, &(&1.entity_name == "Not Due Entity"))
    end

    test "returns records with next_review_date == today" do
      company = company_fixture()
      today = Date.utc_today()

      {:ok, due} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Due Today",
          entity_type: "individual",
          next_review_date: today
        })

      results = Compliance.kyc_due_for_review()
      assert Enum.any?(results, &(&1.id == due.id))
    end
  end

  describe "kyc_summary/0" do
    test "returns counts by status and risk level" do
      company = company_fixture()

      Compliance.create_kyc_record(%{
        company_id: company.id,
        entity_name: "A",
        entity_type: "individual",
        risk_level: "high",
        verification_status: "verified"
      })

      Compliance.create_kyc_record(%{
        company_id: company.id,
        entity_name: "B",
        entity_type: "corporate",
        risk_level: "low",
        verification_status: "not_started"
      })

      summary = Compliance.kyc_summary()
      assert is_list(summary.by_status)
      assert is_list(summary.by_risk)
      assert Enum.any?(summary.by_status, &(&1.status == "verified"))
      assert Enum.any?(summary.by_risk, &(&1.risk_level == "high"))
    end
  end
end
