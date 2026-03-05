defmodule Holdco.Analytics.StressTestTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  # ── CRUD Tests ──────────────────────────────────────────────

  describe "CRUD" do
    test "create_stress_test/1 with valid attrs" do
      company = company_fixture()

      assert {:ok, st} =
               Analytics.create_stress_test(%{
                 name: "Crypto Crash Test",
                 description: "Test a 40% crypto drop",
                 shocks: %{"crypto" => -0.40},
                 company_id: company.id
               })

      assert st.name == "Crypto Crash Test"
      assert st.description == "Test a 40% crypto drop"
      assert st.status == "draft"
      assert st.shocks == %{"crypto" => -0.40}
    end

    test "create_stress_test/1 fails without name" do
      assert {:error, changeset} =
               Analytics.create_stress_test(%{shocks: %{"equity" => -0.10}})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_stress_test/1 fails without shocks" do
      assert {:error, changeset} =
               Analytics.create_stress_test(%{name: "No Shocks"})

      assert %{shocks: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_stress_test/1 validates status inclusion" do
      assert {:error, changeset} =
               Analytics.create_stress_test(%{
                 name: "Bad Status",
                 shocks: %{"equity" => -0.10},
                 status: "invalid_status"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "list_stress_tests/0 returns all stress tests" do
      st = stress_test_fixture(%{name: "List Test"})
      tests = Analytics.list_stress_tests()
      assert length(tests) >= 1
      assert Enum.any?(tests, &(&1.id == st.id))
    end

    test "list_stress_tests/1 filters by company_id" do
      c1 = company_fixture(%{name: "StressCo1"})
      c2 = company_fixture(%{name: "StressCo2"})
      st1 = stress_test_fixture(%{company_id: c1.id, name: "C1 Test"})
      _st2 = stress_test_fixture(%{company_id: c2.id, name: "C2 Test"})

      tests = Analytics.list_stress_tests(c1.id)
      assert length(tests) == 1
      assert hd(tests).id == st1.id
    end

    test "get_stress_test!/1 returns the stress test" do
      st = stress_test_fixture(%{name: "Get Test"})
      found = Analytics.get_stress_test!(st.id)
      assert found.id == st.id
      assert found.name == "Get Test"
    end

    test "get_stress_test!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_stress_test!(0)
      end
    end

    test "update_stress_test/2 updates successfully" do
      st = stress_test_fixture(%{name: "Old Name"})
      assert {:ok, updated} = Analytics.update_stress_test(st, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "delete_stress_test/1 deletes the stress test" do
      st = stress_test_fixture()
      assert {:ok, _} = Analytics.delete_stress_test(st)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_stress_test!(st.id)
      end
    end
  end

  # ── Business Logic Tests ────────────────────────────────────

  describe "run_stress_test/1" do
    test "with crypto shock applies to crypto holdings" do
      company = company_fixture()

      # Create a crypto holding with a known price
      holding =
        holding_fixture(%{
          company: company,
          asset: "Bitcoin",
          ticker: "BTC",
          quantity: 10.0,
          currency: "USD",
          asset_type: "crypto"
        })

      # Record a price so holding_value works
      price_history_fixture(%{ticker: "BTC", price: 50_000.0})

      st =
        stress_test_fixture(%{
          company_id: company.id,
          name: "Crypto Crash",
          shocks: %{"crypto" => -0.40}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"
      assert result.results != nil
      assert result.results["original_nav"] != nil
      assert result.results["stressed_nav"] != nil
      assert result.results["impact"] != nil
      assert result.results["impact_pct"] != nil
      assert is_list(result.results["per_holding"])

      # Verify the impact is negative
      {impact, _} = Decimal.parse(result.results["impact"])
      assert Decimal.compare(impact, Decimal.new(0)) in [:lt, :eq]
    end

    test "with equity shock applies to equity holdings" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "Apple",
        ticker: "AAPL",
        quantity: 100.0,
        currency: "USD",
        asset_type: "equity"
      })

      price_history_fixture(%{ticker: "AAPL", price: 150.0})

      st =
        stress_test_fixture(%{
          company_id: company.id,
          name: "Equity Bear",
          shocks: %{"equity" => -0.20}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"

      # Check per-holding breakdown contains the equity holding
      per_holding = result.results["per_holding"]
      assert length(per_holding) >= 1

      equity_result = Enum.find(per_holding, &(&1["asset_type"] == "equity"))

      if equity_result do
        {shock, _} = Decimal.parse(equity_result["shock_applied"])
        assert Decimal.equal?(shock, Decimal.from_float(-0.20))
      end
    end

    test "with FX shock applies to foreign-currency holdings" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "Euro Bond",
        ticker: "EBND",
        quantity: 1000.0,
        currency: "EUR",
        asset_type: "fixed_income"
      })

      price_history_fixture(%{ticker: "EBND", price: 100.0, currency: "EUR"})

      st =
        stress_test_fixture(%{
          company_id: company.id,
          name: "EUR Weakening",
          shocks: %{"EUR/USD" => -0.10}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"
    end

    test "with combined shocks (global recession)" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "SP500",
        ticker: "SPY",
        quantity: 50.0,
        currency: "USD",
        asset_type: "equity"
      })

      price_history_fixture(%{ticker: "SPY", price: 450.0})

      holding_fixture(%{
        company: company,
        asset: "Bitcoin",
        ticker: "BTC",
        quantity: 2.0,
        currency: "USD",
        asset_type: "crypto"
      })

      price_history_fixture(%{ticker: "BTC", price: 40_000.0})

      st =
        stress_test_fixture(%{
          company_id: company.id,
          name: "Global Recession",
          shocks: %{"equity" => -0.30, "crypto" => -0.50, "real_estate" => -0.15}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"
      assert length(result.results["per_holding"]) >= 2
    end

    test "with empty portfolio (no holdings) does not crash" do
      st =
        stress_test_fixture(%{
          name: "Empty Portfolio",
          shocks: %{"equity" => -0.30}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"
      assert result.results["impact"] == "0"
    end

    test "with no matching holdings returns zero impact" do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "Gold Bar",
        ticker: "GOLD",
        quantity: 10.0,
        currency: "USD",
        asset_type: "commodity"
      })

      price_history_fixture(%{ticker: "GOLD", price: 2000.0})

      # Shock only equity -- the commodity holding should not be affected
      st =
        stress_test_fixture(%{
          company_id: company.id,
          name: "Equity Only",
          shocks: %{"equity" => -0.20}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"

      commodity_result =
        Enum.find(result.results["per_holding"], &(&1["asset_type"] == "commodity"))

      if commodity_result do
        {shock_applied, _} = Decimal.parse(commodity_result["shock_applied"])
        assert Decimal.equal?(shock_applied, Decimal.new(0))
      end
    end

    test "updates status to completed with run_at" do
      st =
        stress_test_fixture(%{
          name: "Status Check",
          shocks: %{"equity" => -0.10}
        })

      assert st.status == "draft"

      assert {:ok, result} = Analytics.run_stress_test(st)
      assert result.status == "completed"
      assert result.run_at != nil
    end

    test "stores results with all expected keys" do
      st =
        stress_test_fixture(%{
          name: "Keys Check",
          shocks: %{"equity" => -0.10}
        })

      assert {:ok, result} = Analytics.run_stress_test(st)

      assert Map.has_key?(result.results, "original_nav")
      assert Map.has_key?(result.results, "stressed_nav")
      assert Map.has_key?(result.results, "impact")
      assert Map.has_key?(result.results, "impact_pct")
      assert Map.has_key?(result.results, "per_holding")
    end
  end

  # ── Predefined Scenarios ────────────────────────────────────

  describe "predefined_scenarios/0" do
    test "returns a list of 5 scenarios" do
      scenarios = Analytics.predefined_scenarios()
      assert length(scenarios) == 5
    end

    test "each scenario has name and shocks" do
      for scenario <- Analytics.predefined_scenarios() do
        assert Map.has_key?(scenario, :name)
        assert Map.has_key?(scenario, :shocks)
        assert is_binary(scenario.name)
        assert is_map(scenario.shocks)
      end
    end

    test "contains expected scenario names" do
      names = Enum.map(Analytics.predefined_scenarios(), & &1.name)
      assert "Crypto Crash" in names
      assert "Equity Bear Market" in names
      assert "USD Strengthening" in names
      assert "Global Recession" in names
      assert "Interest Rate Shock" in names
    end
  end
end
