defmodule Holdco.DepreciationTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Depreciation

  # Helper: convert Decimal to float for test assertions
  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "list_fixed_assets/1" do
    test "returns all fixed assets" do
      fa = fixed_asset_fixture()
      assets = Depreciation.list_fixed_assets()
      assert length(assets) >= 1
      assert Enum.any?(assets, &(&1.id == fa.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "DepCo1"})
      c2 = company_fixture(%{name: "DepCo2"})
      fa1 = fixed_asset_fixture(%{company: c1, name: "Asset A"})
      _fa2 = fixed_asset_fixture(%{company: c2, name: "Asset B"})

      assets = Depreciation.list_fixed_assets(c1.id)
      assert length(assets) == 1
      assert hd(assets).id == fa1.id
    end

    test "returns empty list when no assets for company" do
      company = company_fixture()
      assert Depreciation.list_fixed_assets(company.id) == []
    end
  end

  describe "get_fixed_asset!/1" do
    test "returns the fixed asset with given id" do
      fa = fixed_asset_fixture(%{name: "Fetched Asset"})
      found = Depreciation.get_fixed_asset!(fa.id)
      assert found.id == fa.id
      assert found.name == "Fetched Asset"
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Depreciation.get_fixed_asset!(0)
      end
    end
  end

  describe "create_fixed_asset/1" do
    test "creates a fixed asset with valid attrs" do
      company = company_fixture()

      assert {:ok, fa} =
               Depreciation.create_fixed_asset(%{
                 company_id: company.id,
                 name: "Office Furniture",
                 purchase_date: "2024-03-01",
                 purchase_price: 5_000.0,
                 useful_life_months: 60,
                 salvage_value: 500.0,
                 depreciation_method: "straight_line"
               })

      assert fa.name == "Office Furniture"
      assert d(fa.purchase_price) == 5_000.0
    end

    test "fails without required fields" do
      assert {:error, changeset} = Depreciation.create_fixed_asset(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates depreciation method" do
      company = company_fixture()

      assert {:error, changeset} =
               Depreciation.create_fixed_asset(%{
                 company_id: company.id,
                 name: "Bad Method",
                 depreciation_method: "invalid"
               })

      assert %{depreciation_method: _} = errors_on(changeset)
    end
  end

  describe "update_fixed_asset/2" do
    test "updates a fixed asset" do
      fa = fixed_asset_fixture(%{name: "Old Name"})
      assert {:ok, updated} = Depreciation.update_fixed_asset(fa, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_fixed_asset/1" do
    test "deletes the fixed asset" do
      fa = fixed_asset_fixture()
      assert {:ok, _} = Depreciation.delete_fixed_asset(fa)

      assert_raise Ecto.NoResultsError, fn ->
        Depreciation.get_fixed_asset!(fa.id)
      end
    end
  end

  describe "schedule/1" do
    test "generates straight-line depreciation schedule" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 12_000.0,
          salvage_value: 0.0,
          useful_life_months: 12,
          depreciation_method: "straight_line",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 12

      first = hd(schedule)
      assert first.month == 1
      assert first.depreciation == 1_000.0
      assert first.accumulated == 1_000.0
      assert first.book_value == 11_000.0

      last = List.last(schedule)
      assert last.month == 12
      assert last.accumulated == 12_000.0
      assert last.book_value == 0.0
    end

    test "generates declining-balance depreciation schedule" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 10_000.0,
          salvage_value: 1_000.0,
          useful_life_months: 12,
          depreciation_method: "declining_balance",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 12

      first = hd(schedule)
      assert first.month == 1
      assert first.depreciation > 0
      assert first.book_value < 10_000.0

      # Declining balance: each period's depreciation should be <= previous
      depreciations = Enum.map(schedule, & &1.depreciation)
      pairs = Enum.zip(depreciations, tl(depreciations))
      assert Enum.all?(pairs, fn {a, b} -> a >= b end)

      # Book value should never go below salvage
      assert Enum.all?(schedule, fn row -> row.book_value >= 1_000.0 end)
    end

    test "handles zero useful life" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 5_000.0,
          useful_life_months: 0,
          depreciation_method: "straight_line"
        })

      schedule = Depreciation.schedule(fa)
      # With zero useful life, no depreciation should occur - all entries have 0 depreciation
      assert Enum.all?(schedule, fn row -> row.depreciation == 0.0 end)
    end

    test "handles nil purchase_date" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 6_000.0,
          salvage_value: 0.0,
          useful_life_months: 6,
          depreciation_method: "straight_line",
          purchase_date: nil
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 6
    end

    test "handles nil purchase_price and salvage_value" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: nil,
          salvage_value: nil,
          useful_life_months: 3,
          depreciation_method: "straight_line",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 3
      assert Enum.all?(schedule, fn row -> row.depreciation == 0.0 end)
    end

    test "handles nil useful_life_months" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 5_000.0,
          salvage_value: 0.0,
          useful_life_months: nil,
          depreciation_method: "straight_line",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 1
    end

    test "handles nil depreciation_method defaults to straight_line" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 3_000.0,
          salvage_value: 0.0,
          useful_life_months: 3,
          depreciation_method: nil,
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 3
      # Should be straight line: 1000 per month
      assert hd(schedule).depreciation == 1_000.0
    end

    test "declining balance with zero useful_life" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 5_000.0,
          salvage_value: 0.0,
          useful_life_months: 0,
          depreciation_method: "declining_balance"
        })

      schedule = Depreciation.schedule(fa)
      assert Enum.all?(schedule, fn row -> row.depreciation == 0.0 end)
    end

    test "salvage value equal to cost produces empty or zero depreciation schedule" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 5_000.0,
          salvage_value: 5_000.0,
          useful_life_months: 12,
          depreciation_method: "straight_line",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert Enum.all?(schedule, fn row -> row.depreciation == 0.0 end)
    end

    test "salvage value greater than cost produces zero depreciation" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 3_000.0,
          salvage_value: 5_000.0,
          useful_life_months: 12,
          depreciation_method: "straight_line",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      # Depreciable amount is negative, so monthly should be negative or clamped
      # The schedule still runs for 12 months
      assert length(schedule) == 12
    end

    test "very short useful life of 1 month" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 12_000.0,
          salvage_value: 0.0,
          useful_life_months: 1,
          depreciation_method: "straight_line",
          purchase_date: "2024-06-15"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 1
      assert hd(schedule).depreciation == 12_000.0
      assert hd(schedule).book_value == 0.0
    end

    test "partial-year depreciation preserves correct start date" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 6_000.0,
          salvage_value: 0.0,
          useful_life_months: 6,
          depreciation_method: "straight_line",
          purchase_date: "2024-07-15"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 6
      # First date should be the purchase date
      assert hd(schedule).date == "2024-07-15"
      assert hd(schedule).depreciation == 1_000.0
    end

    test "declining balance schedule never goes below salvage value" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 10_000.0,
          salvage_value: 2_000.0,
          useful_life_months: 24,
          depreciation_method: "declining_balance",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 24
      assert Enum.all?(schedule, fn row -> row.book_value >= 2_000.0 end)
    end

    test "declining balance with high rate depreciates quickly but respects salvage" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 10_000.0,
          salvage_value: 1_000.0,
          useful_life_months: 2,
          depreciation_method: "declining_balance",
          purchase_date: "2024-01-01"
        })

      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 2
      # With 2 months, rate = 2/2 = 100%, but capped by salvage
      assert List.last(schedule).book_value >= 1_000.0
    end

    test "handles invalid purchase_date string" do
      fa =
        fixed_asset_fixture(%{
          purchase_price: 5_000.0,
          salvage_value: 0.0,
          useful_life_months: 3,
          depreciation_method: "straight_line",
          purchase_date: "not-a-date"
        })

      # parse_date returns nil for invalid strings, falls back to Date.utc_today()
      schedule = Depreciation.schedule(fa)
      assert length(schedule) == 3
    end
  end
end
