defmodule Holdco.TransferPricingStudyTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "list_transfer_pricing_studies/1" do
    test "returns all studies" do
      tps = transfer_pricing_study_fixture()
      studies = Compliance.list_transfer_pricing_studies()
      assert length(studies) >= 1
      assert Enum.any?(studies, &(&1.id == tps.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "TPCo1"})
      c2 = company_fixture(%{name: "TPCo2"})
      tps1 = transfer_pricing_study_fixture(%{company: c1, study_name: "Study A"})
      _tps2 = transfer_pricing_study_fixture(%{company: c2, study_name: "Study B"})

      studies = Compliance.list_transfer_pricing_studies(c1.id)
      assert length(studies) == 1
      assert hd(studies).id == tps1.id
    end

    test "returns empty list when no studies for company" do
      company = company_fixture()
      assert Compliance.list_transfer_pricing_studies(company.id) == []
    end
  end

  describe "get_transfer_pricing_study!/1" do
    test "returns the study with given id" do
      tps = transfer_pricing_study_fixture(%{study_name: "Fetched Study"})
      found = Compliance.get_transfer_pricing_study!(tps.id)
      assert found.id == tps.id
      assert found.study_name == "Fetched Study"
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_transfer_pricing_study!(0)
      end
    end
  end

  describe "create_transfer_pricing_study/1" do
    test "creates a study with valid attrs" do
      company = company_fixture()

      assert {:ok, tps} =
               Compliance.create_transfer_pricing_study(%{
                 company_id: company.id,
                 study_name: "Management Fee Study",
                 fiscal_year: 2025,
                 related_party_name: "SubCo LLC",
                 transaction_type: "services",
                 transaction_amount: 500_000.0,
                 currency: "USD",
                 method: "tnmm",
                 arm_length_range_low: 3.0,
                 arm_length_range_high: 8.0,
                 tested_party_margin: 5.5,
                 conclusion: "within_range",
                 adjustment_needed: 0,
                 documentation_status: "complete"
               })

      assert tps.study_name == "Management Fee Study"
      assert tps.method == "tnmm"
      assert tps.transaction_type == "services"
      assert Decimal.equal?(tps.transaction_amount, Decimal.new("500000.0"))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Compliance.create_transfer_pricing_study(%{})
      errors = errors_on(changeset)
      assert %{study_name: ["can't be blank"]} = errors
      assert %{fiscal_year: ["can't be blank"]} = errors
      assert %{related_party_name: ["can't be blank"]} = errors
    end

    test "validates transaction_type inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_transfer_pricing_study(%{
                 company_id: company.id,
                 study_name: "Bad Type",
                 fiscal_year: 2025,
                 related_party_name: "Corp",
                 transaction_type: "invalid"
               })

      assert %{transaction_type: _} = errors_on(changeset)
    end

    test "validates method inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_transfer_pricing_study(%{
                 company_id: company.id,
                 study_name: "Bad Method",
                 fiscal_year: 2025,
                 related_party_name: "Corp",
                 method: "invalid"
               })

      assert %{method: _} = errors_on(changeset)
    end

    test "validates conclusion inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_transfer_pricing_study(%{
                 company_id: company.id,
                 study_name: "Bad Conclusion",
                 fiscal_year: 2025,
                 related_party_name: "Corp",
                 conclusion: "invalid"
               })

      assert %{conclusion: _} = errors_on(changeset)
    end

    test "validates documentation_status inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_transfer_pricing_study(%{
                 company_id: company.id,
                 study_name: "Bad DocStatus",
                 fiscal_year: 2025,
                 related_party_name: "Corp",
                 documentation_status: "invalid"
               })

      assert %{documentation_status: _} = errors_on(changeset)
    end

    test "accepts all valid transaction types" do
      company = company_fixture()

      for type <- ~w(goods services ip_licensing financing cost_sharing) do
        assert {:ok, _} =
                 Compliance.create_transfer_pricing_study(%{
                   company_id: company.id,
                   study_name: "Study #{type}",
                   fiscal_year: 2025,
                   related_party_name: "Corp #{type}",
                   transaction_type: type
                 })
      end
    end

    test "accepts all valid methods" do
      company = company_fixture()

      for method <- ~w(cup resale_price cost_plus tnmm profit_split) do
        assert {:ok, _} =
                 Compliance.create_transfer_pricing_study(%{
                   company_id: company.id,
                   study_name: "Study #{method}",
                   fiscal_year: 2025,
                   related_party_name: "Corp #{method}",
                   method: method
                 })
      end
    end
  end

  describe "update_transfer_pricing_study/2" do
    test "updates a study" do
      tps = transfer_pricing_study_fixture(%{study_name: "Old Name"})
      assert {:ok, updated} = Compliance.update_transfer_pricing_study(tps, %{study_name: "New Name"})
      assert updated.study_name == "New Name"
    end

    test "updates conclusion and adjustment" do
      tps = transfer_pricing_study_fixture(%{conclusion: "within_range", adjustment_needed: 0})

      assert {:ok, updated} =
               Compliance.update_transfer_pricing_study(tps, %{
                 conclusion: "below_range",
                 adjustment_needed: 25_000.0
               })

      assert updated.conclusion == "below_range"
      assert Decimal.equal?(updated.adjustment_needed, Decimal.new("25000.0"))
    end
  end

  describe "delete_transfer_pricing_study/1" do
    test "deletes the study" do
      tps = transfer_pricing_study_fixture()
      assert {:ok, _} = Compliance.delete_transfer_pricing_study(tps)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_transfer_pricing_study!(tps.id)
      end
    end
  end

  describe "transfer_pricing_summary/1" do
    test "returns empty summary when no studies" do
      company = company_fixture()
      summary = Compliance.transfer_pricing_summary(company.id)
      assert summary.by_method == []
      assert summary.needing_adjustment_count == 0
      assert Decimal.equal?(summary.total_adjustment_amount, Decimal.new(0))
    end

    test "aggregates by method" do
      company = company_fixture()

      transfer_pricing_study_fixture(%{
        company: company,
        method: "cup",
        transaction_amount: 100_000.0,
        adjustment_needed: 0
      })

      transfer_pricing_study_fixture(%{
        company: company,
        method: "cup",
        transaction_amount: 200_000.0,
        adjustment_needed: 0
      })

      transfer_pricing_study_fixture(%{
        company: company,
        method: "tnmm",
        transaction_amount: 50_000.0,
        adjustment_needed: 0
      })

      summary = Compliance.transfer_pricing_summary(company.id)
      assert length(summary.by_method) == 2

      cup_row = Enum.find(summary.by_method, &(&1.method == "cup"))
      assert cup_row.count == 2
      assert Decimal.equal?(cup_row.total_amount, Decimal.new("300000.0"))
    end

    test "counts studies needing adjustment" do
      company = company_fixture()

      transfer_pricing_study_fixture(%{
        company: company,
        adjustment_needed: 10_000.0
      })

      transfer_pricing_study_fixture(%{
        company: company,
        adjustment_needed: 5_000.0
      })

      transfer_pricing_study_fixture(%{
        company: company,
        adjustment_needed: 0
      })

      summary = Compliance.transfer_pricing_summary(company.id)
      assert summary.needing_adjustment_count == 2
      assert Decimal.equal?(summary.total_adjustment_amount, Decimal.new("15000.0"))
    end

    test "filters by company when provided" do
      c1 = company_fixture(%{name: "SumCo1"})
      c2 = company_fixture(%{name: "SumCo2"})

      transfer_pricing_study_fixture(%{company: c1, adjustment_needed: 10_000.0})
      transfer_pricing_study_fixture(%{company: c2, adjustment_needed: 20_000.0})

      summary1 = Compliance.transfer_pricing_summary(c1.id)
      assert summary1.needing_adjustment_count == 1
      assert Decimal.equal?(summary1.total_adjustment_amount, Decimal.new("10000.0"))

      summary2 = Compliance.transfer_pricing_summary(c2.id)
      assert summary2.needing_adjustment_count == 1
      assert Decimal.equal?(summary2.total_adjustment_amount, Decimal.new("20000.0"))
    end
  end
end
