defmodule Holdco.ScenariosTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Scenarios

  describe "scenarios" do
    test "CRUD operations" do
      {:ok, s} = Scenarios.create_scenario(%{name: "Bull Case"})

      assert Enum.any?(Scenarios.list_scenarios(), &(&1.id == s.id))
      assert Scenarios.get_scenario!(s.id).id == s.id

      {:ok, updated} = Scenarios.update_scenario(s, %{name: "Bear Case"})
      assert updated.name == "Bear Case"

      {:ok, _} = Scenarios.delete_scenario(updated)
    end

    test "create_scenario/1 invalid" do
      assert {:error, cs} = Scenarios.create_scenario(%{})
      assert errors_on(cs)[:name]
    end
  end

  describe "scenario_items" do
    test "CRUD operations" do
      scenario = scenario_fixture()
      {:ok, si} = Scenarios.create_scenario_item(%{scenario_id: scenario.id, name: "SaaS Revenue", item_type: "revenue", amount: 50_000.0})

      assert Enum.any?(Scenarios.list_scenario_items(scenario.id), &(&1.id == si.id))
      assert Scenarios.get_scenario_item!(si.id).id == si.id

      {:ok, updated} = Scenarios.update_scenario_item(si, %{amount: 60_000.0})
      assert updated.amount == 60_000.0

      {:ok, _} = Scenarios.delete_scenario_item(updated)
    end
  end

  describe "projection engine" do
    test "project/1 returns monthly projections" do
      scenario = scenario_fixture(%{projection_months: 6})
      scenario_item_fixture(%{scenario: scenario, name: "Revenue", item_type: "revenue", amount: 10_000.0})

      projections = Scenarios.project(scenario)
      assert length(projections) == 6
      assert Enum.all?(projections, &(is_map(&1) and Map.has_key?(&1, :month)))
    end

    test "project/1 handles compound growth" do
      scenario = scenario_fixture(%{projection_months: 3})
      scenario_item_fixture(%{
        scenario: scenario, name: "Rev", item_type: "revenue",
        amount: 1000.0, growth_rate: 10.0, growth_type: "compound", recurrence: "monthly"
      })

      projections = Scenarios.project(scenario)
      assert length(projections) == 3
      # Month 1: 1000, Month 2: 1000 * 1.1, Month 3: 1000 * 1.1^2
      assert hd(projections).revenue == 1000.0
      assert Enum.at(projections, 1).revenue > 1000.0
    end

    test "project/1 handles linear growth" do
      scenario = scenario_fixture(%{projection_months: 3})
      scenario_item_fixture(%{
        scenario: scenario, name: "Rev", item_type: "revenue",
        amount: 1000.0, growth_rate: 10.0, growth_type: "linear", recurrence: "monthly"
      })

      projections = Scenarios.project(scenario)
      assert hd(projections).revenue == 1000.0
    end

    test "project/1 handles quarterly recurrence" do
      scenario = scenario_fixture(%{projection_months: 6})
      scenario_item_fixture(%{
        scenario: scenario, name: "Quarterly Expense", item_type: "expense",
        amount: 5000.0, recurrence: "quarterly"
      })

      projections = Scenarios.project(scenario)
      # Only months 3 and 6 should have expenses
      assert Enum.at(projections, 0).expenses == 0.0
      assert Enum.at(projections, 2).expenses == 5000.0
    end

    test "project/1 handles probability weighting" do
      scenario = scenario_fixture(%{projection_months: 1})
      scenario_item_fixture(%{
        scenario: scenario, name: "Rev", item_type: "revenue",
        amount: 1000.0, probability: 0.5, recurrence: "monthly"
      })

      projections = Scenarios.project(scenario)
      assert hd(projections).revenue == 500.0
    end

    test "project/1 calculates net correctly" do
      scenario = scenario_fixture(%{projection_months: 1})
      scenario_item_fixture(%{scenario: scenario, name: "Rev", item_type: "revenue", amount: 10_000.0, recurrence: "monthly"})
      scenario_item_fixture(%{scenario: scenario, name: "Exp", item_type: "expense", amount: 3_000.0, recurrence: "monthly"})

      [projection] = Scenarios.project(scenario)
      assert projection.net == 7_000.0
    end
  end
end
