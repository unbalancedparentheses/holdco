defmodule Holdco.GoodwillTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Finance

  defp d(val) when is_struct(val, Decimal), do: Decimal.to_float(val)
  defp d(val) when is_number(val), do: val / 1
  defp d(nil), do: 0.0

  describe "goodwill CRUD" do
    test "create_goodwill/1 with valid data" do
      company = company_fixture()

      attrs = %{
        company_id: company.id,
        acquisition_name: "Acme Corp Acquisition",
        acquisition_date: "2024-01-15",
        original_amount: 5_000_000.0,
        carrying_value: 5_000_000.0,
        reporting_unit: "North America",
        status: "active"
      }

      assert {:ok, gw} = Finance.create_goodwill(attrs)
      assert gw.acquisition_name == "Acme Corp Acquisition"
      assert d(gw.original_amount) == 5_000_000.0
      assert d(gw.carrying_value) == 5_000_000.0
      assert d(gw.accumulated_impairment) == 0.0
      assert gw.status == "active"
    end

    test "create_goodwill/1 with invalid data" do
      assert {:error, cs} = Finance.create_goodwill(%{})
      assert errors_on(cs)[:company_id]
      assert errors_on(cs)[:acquisition_name]
      assert errors_on(cs)[:original_amount]
      assert errors_on(cs)[:carrying_value]
    end

    test "create_goodwill/1 rejects invalid status" do
      company = company_fixture()

      assert {:error, cs} =
        Finance.create_goodwill(%{
          company_id: company.id,
          acquisition_name: "Test",
          original_amount: 1_000.0,
          carrying_value: 1_000.0,
          status: "invalid"
        })

      assert errors_on(cs)[:status]
    end

    test "list_goodwill/0 returns all goodwill records" do
      gw = goodwill_fixture()
      records = Finance.list_goodwill()
      assert Enum.any?(records, &(&1.id == gw.id))
    end

    test "list_goodwill/1 filters by company_id" do
      company = company_fixture()
      gw = goodwill_fixture(%{company: company})
      _other = goodwill_fixture()

      records = Finance.list_goodwill(company.id)
      assert Enum.all?(records, &(&1.company_id == company.id))
      assert Enum.any?(records, &(&1.id == gw.id))
    end

    test "get_goodwill!/1 returns the record with preloads" do
      gw = goodwill_fixture()
      fetched = Finance.get_goodwill!(gw.id)
      assert fetched.id == gw.id
      assert fetched.company != nil
    end

    test "update_goodwill/2 with valid data" do
      gw = goodwill_fixture()
      {:ok, updated} = Finance.update_goodwill(gw, %{reporting_unit: "Europe", notes: "Updated"})
      assert updated.reporting_unit == "Europe"
      assert updated.notes == "Updated"
    end

    test "delete_goodwill/1 removes the record" do
      gw = goodwill_fixture()
      {:ok, _} = Finance.delete_goodwill(gw)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_goodwill!(gw.id) end
    end
  end

  describe "impairment_tests CRUD" do
    test "create_impairment_test/1 with valid data" do
      gw = goodwill_fixture()

      attrs = %{
        goodwill_id: gw.id,
        test_date: "2024-06-30",
        fair_value: 800_000.0,
        carrying_amount: 1_000_000.0,
        impairment_amount: 200_000.0,
        method: "income_approach",
        discount_rate: 10.0,
        growth_rate: 3.0,
        result: "impairment_recognized",
        assumptions: "DCF model with 5-year projections",
        notes: "Annual test"
      }

      assert {:ok, it} = Finance.create_impairment_test(attrs)
      assert it.goodwill_id == gw.id
      assert d(it.fair_value) == 800_000.0
      assert it.result == "impairment_recognized"
      assert it.method == "income_approach"
    end

    test "create_impairment_test/1 with invalid data" do
      assert {:error, cs} = Finance.create_impairment_test(%{})
      assert errors_on(cs)[:goodwill_id]
      assert errors_on(cs)[:test_date]
      assert errors_on(cs)[:fair_value]
      assert errors_on(cs)[:method]
      assert errors_on(cs)[:result]
    end

    test "create_impairment_test/1 rejects invalid method" do
      gw = goodwill_fixture()

      assert {:error, cs} =
        Finance.create_impairment_test(%{
          goodwill_id: gw.id,
          test_date: "2024-06-30",
          fair_value: 800_000.0,
          carrying_amount: 1_000_000.0,
          method: "invalid_method",
          result: "no_impairment"
        })

      assert errors_on(cs)[:method]
    end

    test "list_impairment_tests/1 returns tests for a goodwill record" do
      gw = goodwill_fixture()
      it = impairment_test_fixture(%{goodwill: gw})
      tests = Finance.list_impairment_tests(gw.id)
      assert Enum.any?(tests, &(&1.id == it.id))
    end

    test "get_impairment_test!/1 returns the test with preloads" do
      it = impairment_test_fixture()
      fetched = Finance.get_impairment_test!(it.id)
      assert fetched.id == it.id
      assert fetched.goodwill != nil
    end

    test "update_impairment_test/2" do
      it = impairment_test_fixture()
      {:ok, updated} = Finance.update_impairment_test(it, %{notes: "Reviewed"})
      assert updated.notes == "Reviewed"
    end

    test "delete_impairment_test/1 removes the record" do
      it = impairment_test_fixture()
      {:ok, _} = Finance.delete_impairment_test(it)
      assert_raise Ecto.NoResultsError, fn -> Finance.get_impairment_test!(it.id) end
    end
  end

  describe "run_impairment_test/2" do
    test "recognizes impairment when fair_value < carrying_value" do
      company = company_fixture()

      {:ok, gw} =
        Finance.create_goodwill(%{
          company_id: company.id,
          acquisition_name: "Target Corp",
          original_amount: 1_000_000.0,
          carrying_value: 1_000_000.0
        })

      assert {:ok, %{test: test, goodwill: updated_gw}} =
        Finance.run_impairment_test(gw.id, %{
          fair_value: 750_000.0,
          method: "income_approach",
          test_date: "2024-12-31",
          discount_rate: 10.0,
          growth_rate: 2.0
        })

      assert test.result == "impairment_recognized"
      assert d(test.impairment_amount) == 250_000.0
      assert d(test.fair_value) == 750_000.0
      assert d(test.carrying_amount) == 1_000_000.0

      assert d(updated_gw.accumulated_impairment) == 250_000.0
      assert d(updated_gw.carrying_value) == 750_000.0
      assert updated_gw.last_test_date == "2024-12-31"
      assert updated_gw.status == "active"
    end

    test "no impairment when fair_value >= carrying_value" do
      company = company_fixture()

      {:ok, gw} =
        Finance.create_goodwill(%{
          company_id: company.id,
          acquisition_name: "Strong Corp",
          original_amount: 500_000.0,
          carrying_value: 500_000.0
        })

      assert {:ok, %{test: test, goodwill: updated_gw}} =
        Finance.run_impairment_test(gw.id, %{
          fair_value: 600_000.0,
          method: "market_approach",
          test_date: "2024-12-31"
        })

      assert test.result == "no_impairment"
      assert d(test.impairment_amount) == 0.0
      assert d(updated_gw.carrying_value) == 500_000.0
      assert d(updated_gw.accumulated_impairment) == 0.0
    end

    test "fully impairs when fair_value is 0" do
      company = company_fixture()

      {:ok, gw} =
        Finance.create_goodwill(%{
          company_id: company.id,
          acquisition_name: "Failed Corp",
          original_amount: 200_000.0,
          carrying_value: 200_000.0
        })

      assert {:ok, %{test: _test, goodwill: updated_gw}} =
        Finance.run_impairment_test(gw.id, %{
          fair_value: 0.0,
          method: "cost_approach",
          test_date: "2024-12-31"
        })

      assert updated_gw.status == "fully_impaired"
      assert d(updated_gw.carrying_value) == 0.0
      assert d(updated_gw.accumulated_impairment) == 200_000.0
    end

    test "cumulative impairments accumulate correctly" do
      company = company_fixture()

      {:ok, gw} =
        Finance.create_goodwill(%{
          company_id: company.id,
          acquisition_name: "Declining Corp",
          original_amount: 1_000_000.0,
          carrying_value: 1_000_000.0
        })

      # First impairment
      {:ok, %{goodwill: gw_after_1}} =
        Finance.run_impairment_test(gw.id, %{
          fair_value: 800_000.0,
          method: "income_approach",
          test_date: "2024-06-30"
        })

      assert d(gw_after_1.accumulated_impairment) == 200_000.0
      assert d(gw_after_1.carrying_value) == 800_000.0

      # Second impairment
      {:ok, %{goodwill: gw_after_2}} =
        Finance.run_impairment_test(gw.id, %{
          fair_value: 500_000.0,
          method: "income_approach",
          test_date: "2024-12-31"
        })

      assert d(gw_after_2.accumulated_impairment) == 500_000.0
      assert d(gw_after_2.carrying_value) == 500_000.0
    end

    test "all impairment test methods are accepted" do
      gw = goodwill_fixture()

      for method <- ~w(income_approach market_approach cost_approach) do
        assert {:ok, %{test: test}} =
          Finance.run_impairment_test(gw.id, %{
            fair_value: 2_000_000.0,
            method: method,
            test_date: "2024-12-31"
          })

        assert test.method == method
      end
    end
  end
end
