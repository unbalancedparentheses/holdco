defmodule Holdco.Fund.FundNavTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  describe "list_fund_navs/1" do
    test "returns all fund navs" do
      nav = fund_nav_fixture()
      navs = Fund.list_fund_navs()
      assert length(navs) >= 1
      assert Enum.any?(navs, &(&1.id == nav.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "NAV Co1"})
      c2 = company_fixture(%{name: "NAV Co2"})
      nav1 = fund_nav_fixture(%{company: c1, nav_date: ~D[2024-01-01]})
      _nav2 = fund_nav_fixture(%{company: c2, nav_date: ~D[2024-01-01]})

      navs = Fund.list_fund_navs(c1.id)
      assert length(navs) == 1
      assert hd(navs).id == nav1.id
    end

    test "returns empty list when no navs for company" do
      company = company_fixture()
      assert Fund.list_fund_navs(company.id) == []
    end
  end

  describe "get_fund_nav!/1" do
    test "returns the fund nav with given id" do
      nav = fund_nav_fixture()
      found = Fund.get_fund_nav!(nav.id)
      assert found.id == nav.id
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fund_nav!(0)
      end
    end
  end

  describe "create_fund_nav/1" do
    test "creates a fund nav with valid attrs" do
      company = company_fixture()

      assert {:ok, nav} =
               Fund.create_fund_nav(%{
                 company_id: company.id,
                 nav_date: ~D[2024-06-30],
                 total_assets: 500_000.0,
                 total_liabilities: 100_000.0,
                 net_asset_value: 400_000.0,
                 nav_per_unit: 50.0,
                 units_outstanding: 8_000.0
               })

      assert nav.nav_date == ~D[2024-06-30]
      assert Decimal.equal?(nav.net_asset_value, Decimal.from_float(400_000.0))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_fund_nav(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:nav_date]
    end

    test "enforces unique constraint on company_id + nav_date" do
      company = company_fixture()

      assert {:ok, _} =
               Fund.create_fund_nav(%{
                 company_id: company.id,
                 nav_date: ~D[2024-03-31]
               })

      assert {:error, changeset} =
               Fund.create_fund_nav(%{
                 company_id: company.id,
                 nav_date: ~D[2024-03-31]
               })

      errors = errors_on(changeset)
      assert errors[:company_id] || errors[:nav_date]
    end
  end

  describe "update_fund_nav/2" do
    test "updates a fund nav" do
      nav = fund_nav_fixture()

      assert {:ok, updated} =
               Fund.update_fund_nav(nav, %{net_asset_value: 999_999.0})

      assert Decimal.equal?(updated.net_asset_value, Decimal.from_float(999_999.0))
    end
  end

  describe "delete_fund_nav/1" do
    test "deletes the fund nav" do
      nav = fund_nav_fixture()
      assert {:ok, _} = Fund.delete_fund_nav(nav)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fund_nav!(nav.id)
      end
    end
  end

  describe "calculate_fund_nav/1" do
    test "calculates NAV with bank accounts and no holdings" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 500_000.0})

      result = Fund.calculate_fund_nav(company.id)

      assert Decimal.compare(result.total_assets, Decimal.new(0)) == :gt
      assert result.net_asset_value != nil
    end

    test "calculates NAV including liabilities" do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 1_000_000.0})
      liability_fixture(%{company: company, principal: 200_000.0})

      result = Fund.calculate_fund_nav(company.id)

      # total_assets should include bank balance, liabilities subtract from it
      assert Decimal.compare(result.total_liabilities, Decimal.new(0)) == :gt
      assert Decimal.compare(result.net_asset_value, result.total_assets) == :lt
    end

    test "calculates NAV with holdings (cost basis lots)" do
      company = company_fixture()
      holding = holding_fixture(%{company: company})
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 50.0})

      result = Fund.calculate_fund_nav(company.id)

      # Holdings value should be 100 * 50 = 5000
      assert Decimal.compare(result.total_assets, Decimal.new(0)) == :gt
    end
  end
end
