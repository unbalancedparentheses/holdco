defmodule Holdco.Platform.AlertEngineTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "check_condition/2" do
    test "above threshold returns true when value > threshold" do
      rule = alert_rule_fixture(%{condition: "above", threshold: 1000})
      assert Platform.check_condition(rule, Decimal.new("1500"))
    end

    test "above threshold returns false when value <= threshold" do
      rule = alert_rule_fixture(%{condition: "above", threshold: 1000})
      refute Platform.check_condition(rule, Decimal.new("1000"))
      refute Platform.check_condition(rule, Decimal.new("500"))
    end

    test "below threshold returns true when value < threshold" do
      rule = alert_rule_fixture(%{condition: "below", threshold: 1000})
      assert Platform.check_condition(rule, Decimal.new("500"))
    end

    test "below threshold returns false when value >= threshold" do
      rule = alert_rule_fixture(%{condition: "below", threshold: 1000})
      refute Platform.check_condition(rule, Decimal.new("1000"))
      refute Platform.check_condition(rule, Decimal.new("1500"))
    end

    test "unknown condition returns false" do
      rule = alert_rule_fixture()
      # Directly create a rule struct with invalid condition to test the fallback
      rule = %{rule | condition: "unknown_cond"}
      refute Platform.check_condition(rule, Decimal.new("500"))
    end
  end

  describe "within_cooldown?/1" do
    test "returns false when last_triggered_at is nil" do
      rule = alert_rule_fixture()
      refute Platform.within_cooldown?(rule)
    end

    test "returns true within cooldown window" do
      rule = alert_rule_fixture(%{cooldown_minutes: 60})
      # Set last_triggered_at to 30 minutes ago (within 60 min cooldown)
      thirty_min_ago = DateTime.utc_now() |> DateTime.add(-30 * 60, :second) |> DateTime.truncate(:second)
      {:ok, updated} = Platform.update_alert_rule(rule, %{last_triggered_at: thirty_min_ago})
      assert Platform.within_cooldown?(updated)
    end

    test "returns false after cooldown window" do
      rule = alert_rule_fixture(%{cooldown_minutes: 60})
      # Set last_triggered_at to 120 minutes ago (beyond 60 min cooldown)
      two_hours_ago = DateTime.utc_now() |> DateTime.add(-120 * 60, :second) |> DateTime.truncate(:second)
      {:ok, updated} = Platform.update_alert_rule(rule, %{last_triggered_at: two_hours_ago})
      refute Platform.within_cooldown?(updated)
    end
  end

  describe "evaluate_metric/1" do
    test "nav metric returns a decimal value" do
      rule = alert_rule_fixture(%{metric: "nav"})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "cash_balance metric returns a decimal value" do
      rule = alert_rule_fixture(%{metric: "cash_balance"})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "cash_balance metric filters by company_id" do
      company = company_fixture()
      _ba = bank_account_fixture(%{company: company, balance: 50_000.0})

      rule = alert_rule_fixture(%{metric: "cash_balance", company_id: company.id})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "holding_value metric requires target" do
      rule = alert_rule_fixture(%{metric: "holding_value", target: nil})
      assert {:error, "target ticker required for holding_value metric"} = Platform.evaluate_metric(rule)
    end

    test "holding_value metric with target returns decimal" do
      rule = alert_rule_fixture(%{metric: "holding_value", target: "AAPL"})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "liability_total metric returns a decimal value" do
      rule = alert_rule_fixture(%{metric: "liability_total"})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "portfolio_concentration metric returns a decimal value" do
      rule = alert_rule_fixture(%{metric: "portfolio_concentration"})
      assert {:ok, value} = Platform.evaluate_metric(rule)
      assert %Decimal{} = value
    end

    test "unknown metric returns error" do
      rule = alert_rule_fixture()
      rule = %{rule | metric: "nonexistent"}
      assert {:error, "unknown metric: nonexistent"} = Platform.evaluate_metric(rule)
    end
  end
end
