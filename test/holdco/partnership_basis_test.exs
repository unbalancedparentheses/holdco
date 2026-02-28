defmodule Holdco.PartnershipBasisTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  describe "list_partnership_bases/1" do
    test "returns all bases" do
      pb = partnership_basis_fixture()
      bases = Fund.list_partnership_bases()
      assert length(bases) >= 1
      assert Enum.any?(bases, &(&1.id == pb.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "FundCo1"})
      c2 = company_fixture(%{name: "FundCo2"})
      pb1 = partnership_basis_fixture(%{company: c1, partner_name: "Partner A"})
      _pb2 = partnership_basis_fixture(%{company: c2, partner_name: "Partner B"})

      bases = Fund.list_partnership_bases(c1.id)
      assert length(bases) == 1
      assert hd(bases).id == pb1.id
    end

    test "returns empty list when no bases for company" do
      company = company_fixture()
      assert Fund.list_partnership_bases(company.id) == []
    end

    test "orders by tax_year desc, partner_name asc" do
      company = company_fixture()
      _pb1 = partnership_basis_fixture(%{company: company, partner_name: "Beta", tax_year: 2024})
      _pb2 = partnership_basis_fixture(%{company: company, partner_name: "Alpha", tax_year: 2025})
      _pb3 = partnership_basis_fixture(%{company: company, partner_name: "Alpha", tax_year: 2024})

      bases = Fund.list_partnership_bases(company.id)
      assert [first, second, third] = bases
      assert first.tax_year == 2025
      assert first.partner_name == "Alpha"
      assert second.tax_year == 2024
      assert second.partner_name == "Alpha"
      assert third.tax_year == 2024
      assert third.partner_name == "Beta"
    end
  end

  describe "get_partnership_basis!/1" do
    test "returns the basis with given id" do
      pb = partnership_basis_fixture(%{partner_name: "Fetched Partner"})
      found = Fund.get_partnership_basis!(pb.id)
      assert found.id == pb.id
      assert found.partner_name == "Fetched Partner"
    end

    test "preloads company" do
      pb = partnership_basis_fixture()
      found = Fund.get_partnership_basis!(pb.id)
      assert found.company != nil
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_partnership_basis!(0)
      end
    end
  end

  describe "create_partnership_basis/1" do
    test "creates a basis with valid attrs" do
      company = company_fixture()

      assert {:ok, pb} =
               Fund.create_partnership_basis(%{
                 company_id: company.id,
                 partner_name: "John Smith",
                 tax_year: 2025,
                 beginning_basis: 100_000.0,
                 capital_contributions: 50_000.0,
                 share_of_income: 25_000.0,
                 share_of_losses: 5_000.0,
                 distributions_received: 10_000.0,
                 special_allocations: 2_000.0,
                 section_754_adjustments: 1_000.0,
                 ending_basis: 163_000.0,
                 at_risk_amount: 150_000.0,
                 passive_activity_amount: 20_000.0
               })

      assert pb.partner_name == "John Smith"
      assert pb.tax_year == 2025
      assert Decimal.equal?(pb.beginning_basis, Decimal.new("100000.0"))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_partnership_basis(%{})
      errors = errors_on(changeset)
      assert %{partner_name: ["can't be blank"]} = errors
      assert %{tax_year: ["can't be blank"]} = errors
    end

    test "uses default values for optional decimal fields" do
      company = company_fixture()

      assert {:ok, pb} =
               Fund.create_partnership_basis(%{
                 company_id: company.id,
                 partner_name: "Minimal Partner",
                 tax_year: 2025
               })

      assert Decimal.equal?(pb.beginning_basis, Decimal.new(0))
      assert Decimal.equal?(pb.capital_contributions, Decimal.new(0))
      assert Decimal.equal?(pb.ending_basis, Decimal.new(0))
    end
  end

  describe "update_partnership_basis/2" do
    test "updates a basis" do
      pb = partnership_basis_fixture(%{partner_name: "Old Partner"})
      assert {:ok, updated} = Fund.update_partnership_basis(pb, %{partner_name: "New Partner"})
      assert updated.partner_name == "New Partner"
    end

    test "updates financial fields" do
      pb = partnership_basis_fixture()

      assert {:ok, updated} =
               Fund.update_partnership_basis(pb, %{
                 capital_contributions: 75_000.0,
                 share_of_income: 30_000.0
               })

      assert Decimal.equal?(updated.capital_contributions, Decimal.new("75000.0"))
      assert Decimal.equal?(updated.share_of_income, Decimal.new("30000.0"))
    end
  end

  describe "delete_partnership_basis/1" do
    test "deletes the basis" do
      pb = partnership_basis_fixture()
      assert {:ok, _} = Fund.delete_partnership_basis(pb)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_partnership_basis!(pb.id)
      end
    end
  end

  describe "calculate_ending_basis/1" do
    test "computes ending basis from components" do
      company = company_fixture()

      {:ok, pb} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "Calc Partner",
          tax_year: 2025,
          beginning_basis: 100_000.0,
          capital_contributions: 50_000.0,
          share_of_income: 25_000.0,
          share_of_losses: 5_000.0,
          distributions_received: 10_000.0,
          special_allocations: 2_000.0,
          section_754_adjustments: 1_000.0
        })

      # 100000 + 50000 + 25000 - 5000 - 10000 + 2000 + 1000 = 163000
      result = Fund.calculate_ending_basis(pb)
      assert Decimal.equal?(result, Decimal.new("163000.0"))
    end

    test "handles zero values" do
      company = company_fixture()

      {:ok, pb} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "Zero Partner",
          tax_year: 2025,
          beginning_basis: 0,
          capital_contributions: 0,
          share_of_income: 0,
          share_of_losses: 0,
          distributions_received: 0,
          special_allocations: 0,
          section_754_adjustments: 0
        })

      result = Fund.calculate_ending_basis(pb)
      assert Decimal.equal?(result, Decimal.new(0))
    end

    test "handles large negative adjustments" do
      company = company_fixture()

      {:ok, pb} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "Negative Partner",
          tax_year: 2025,
          beginning_basis: 50_000.0,
          capital_contributions: 0,
          share_of_income: 0,
          share_of_losses: 80_000.0,
          distributions_received: 0,
          special_allocations: 0,
          section_754_adjustments: 0
        })

      # 50000 - 80000 = -30000
      result = Fund.calculate_ending_basis(pb)
      assert Decimal.equal?(result, Decimal.new("-30000.0"))
    end

    test "calculates correctly with only contributions and income" do
      company = company_fixture()

      {:ok, pb} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: "Income Partner",
          tax_year: 2025,
          beginning_basis: 200_000.0,
          capital_contributions: 100_000.0,
          share_of_income: 75_000.0
        })

      # 200000 + 100000 + 75000 = 375000
      result = Fund.calculate_ending_basis(pb)
      assert Decimal.equal?(result, Decimal.new("375000.0"))
    end
  end

  describe "basis_history/2" do
    test "returns multi-year history for a partner" do
      company = company_fixture()
      partner = "History Partner"

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: partner,
          tax_year: 2023,
          beginning_basis: 50_000.0
        })

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: partner,
          tax_year: 2024,
          beginning_basis: 75_000.0
        })

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: company.id,
          partner_name: partner,
          tax_year: 2025,
          beginning_basis: 100_000.0
        })

      history = Fund.basis_history(company.id, partner)
      assert length(history) == 3
      assert [first, second, third] = history
      assert first.tax_year == 2023
      assert second.tax_year == 2024
      assert third.tax_year == 2025
    end

    test "returns empty list for unknown partner" do
      company = company_fixture()
      assert Fund.basis_history(company.id, "Unknown Partner") == []
    end

    test "filters by company - does not return other company's records" do
      c1 = company_fixture(%{name: "HistCo1"})
      c2 = company_fixture(%{name: "HistCo2"})
      partner = "Shared Name"

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: c1.id,
          partner_name: partner,
          tax_year: 2025
        })

      {:ok, _} =
        Fund.create_partnership_basis(%{
          company_id: c2.id,
          partner_name: partner,
          tax_year: 2025
        })

      history = Fund.basis_history(c1.id, partner)
      assert length(history) == 1
      assert hd(history).company_id == c1.id
    end

    test "orders by tax_year ascending" do
      company = company_fixture()
      partner = "Order Partner"

      {:ok, _} = Fund.create_partnership_basis(%{company_id: company.id, partner_name: partner, tax_year: 2025})
      {:ok, _} = Fund.create_partnership_basis(%{company_id: company.id, partner_name: partner, tax_year: 2023})
      {:ok, _} = Fund.create_partnership_basis(%{company_id: company.id, partner_name: partner, tax_year: 2024})

      history = Fund.basis_history(company.id, partner)
      years = Enum.map(history, & &1.tax_year)
      assert years == [2023, 2024, 2025]
    end
  end
end
