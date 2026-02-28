defmodule Holdco.Platform.AlertRuleTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Platform

  describe "create_alert_rule/1" do
    test "creates alert rule with valid attrs" do
      assert {:ok, rule} =
               Platform.create_alert_rule(%{
                 name: "NAV Monitor",
                 metric: "nav",
                 condition: "below",
                 threshold: 1_000_000.0,
                 severity: "critical"
               })

      assert rule.name == "NAV Monitor"
      assert rule.metric == "nav"
      assert rule.condition == "below"
      assert Decimal.equal?(rule.threshold, Decimal.from_float(1_000_000.0))
      assert rule.severity == "critical"
      assert rule.is_active == true
      assert rule.cooldown_minutes == 60
    end

    test "creates alert rule with company and user associations" do
      company = company_fixture()
      user = user_fixture()

      assert {:ok, rule} =
               Platform.create_alert_rule(%{
                 name: "Company Cash",
                 metric: "cash_balance",
                 condition: "below",
                 threshold: 50_000.0,
                 company_id: company.id,
                 created_by_id: user.id
               })

      assert rule.company_id == company.id
      assert rule.created_by_id == user.id
    end

    test "validates required fields" do
      assert {:error, changeset} = Platform.create_alert_rule(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:metric]
      assert errors[:condition]
      assert errors[:threshold]
    end

    test "validates metric inclusion" do
      assert {:error, changeset} =
               Platform.create_alert_rule(%{
                 name: "Bad Metric",
                 metric: "invalid_metric",
                 condition: "above",
                 threshold: 100
               })

      assert "is invalid" in errors_on(changeset)[:metric]
    end

    test "validates condition inclusion" do
      assert {:error, changeset} =
               Platform.create_alert_rule(%{
                 name: "Bad Condition",
                 metric: "nav",
                 condition: "invalid_condition",
                 threshold: 100
               })

      assert "is invalid" in errors_on(changeset)[:condition]
    end

    test "validates severity inclusion" do
      assert {:error, changeset} =
               Platform.create_alert_rule(%{
                 name: "Bad Severity",
                 metric: "nav",
                 condition: "above",
                 threshold: 100,
                 severity: "extreme"
               })

      assert "is invalid" in errors_on(changeset)[:severity]
    end

    test "validates threshold >= 0" do
      assert {:error, changeset} =
               Platform.create_alert_rule(%{
                 name: "Negative Threshold",
                 metric: "nav",
                 condition: "above",
                 threshold: -1
               })

      assert errors_on(changeset)[:threshold]
    end

    test "validates cooldown_minutes > 0" do
      assert {:error, changeset} =
               Platform.create_alert_rule(%{
                 name: "Zero Cooldown",
                 metric: "nav",
                 condition: "above",
                 threshold: 100,
                 cooldown_minutes: 0
               })

      assert errors_on(changeset)[:cooldown_minutes]
    end
  end

  describe "update_alert_rule/2" do
    test "updates alert rule fields" do
      rule = alert_rule_fixture()

      assert {:ok, updated} =
               Platform.update_alert_rule(rule, %{
                 name: "Updated Name",
                 severity: "critical",
                 threshold: 2_000_000.0
               })

      assert updated.name == "Updated Name"
      assert updated.severity == "critical"
      assert Decimal.equal?(updated.threshold, Decimal.from_float(2_000_000.0))
    end

    test "can deactivate a rule" do
      rule = alert_rule_fixture()
      assert {:ok, updated} = Platform.update_alert_rule(rule, %{is_active: false})
      assert updated.is_active == false
    end
  end

  describe "delete_alert_rule/1" do
    test "removes the alert rule" do
      rule = alert_rule_fixture()
      assert {:ok, _} = Platform.delete_alert_rule(rule)
      assert_raise Ecto.NoResultsError, fn -> Platform.get_alert_rule!(rule.id) end
    end
  end

  describe "list_alert_rules/1" do
    test "returns all rules" do
      rule1 = alert_rule_fixture(%{name: "Rule A"})
      rule2 = alert_rule_fixture(%{name: "Rule B"})

      rules = Platform.list_alert_rules()
      rule_ids = Enum.map(rules, & &1.id)

      assert rule1.id in rule_ids
      assert rule2.id in rule_ids
    end

    test "filters by company_id" do
      company = company_fixture()
      _rule1 = alert_rule_fixture(%{name: "No Company"})
      rule2 = alert_rule_fixture(%{name: "With Company", company_id: company.id})

      rules = Platform.list_alert_rules(company.id)
      rule_ids = Enum.map(rules, & &1.id)

      assert rule2.id in rule_ids
      assert length(rules) == 1
    end
  end

  describe "list_active_alert_rules/0" do
    test "only returns active rules" do
      active_rule = alert_rule_fixture(%{name: "Active", is_active: true})
      _inactive_rule = alert_rule_fixture(%{name: "Inactive", is_active: false})

      rules = Platform.list_active_alert_rules()
      rule_ids = Enum.map(rules, & &1.id)

      assert active_rule.id in rule_ids
      assert Enum.all?(rules, & &1.is_active)
    end
  end

  describe "get_alert_rule!/1" do
    test "returns rule with preloads" do
      company = company_fixture()
      user = user_fixture()

      {:ok, rule} =
        Platform.create_alert_rule(%{
          name: "Preload Test",
          metric: "nav",
          condition: "above",
          threshold: 100,
          company_id: company.id,
          created_by_id: user.id
        })

      loaded = Platform.get_alert_rule!(rule.id)
      assert loaded.company.id == company.id
      assert loaded.created_by.id == user.id
      assert is_list(loaded.alerts)
    end
  end
end
