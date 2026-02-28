defmodule Holdco.Workers.AlertEngineWorkerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Workers.AlertEngineWorker
  alias Holdco.Platform

  describe "perform/1" do
    test "worker performs successfully with no rules" do
      assert :ok = AlertEngineWorker.perform(%{})
    end

    test "worker handles active rules without triggering" do
      # Create a rule with a very high threshold (above condition) so NAV won't trigger it
      _rule =
        alert_rule_fixture(%{
          name: "High NAV Alert",
          metric: "nav",
          condition: "above",
          threshold: 999_999_999_999.0,
          is_active: true
        })

      assert :ok = AlertEngineWorker.perform(%{})

      # No alerts should have been created
      alerts = Platform.list_alerts()
      # There may be other alerts from other tests but this particular rule shouldn't trigger
      assert Enum.all?(alerts, fn a -> a.message != "Alert: High NAV Alert" end) ||
               alerts == []
    end

    test "worker creates alert when condition is met" do
      # NAV will be 0 or very low with no data, so "below" a high threshold should trigger
      rule =
        alert_rule_fixture(%{
          name: "Low NAV Alert",
          metric: "nav",
          condition: "below",
          threshold: 999_999_999.0,
          severity: "critical",
          is_active: true
        })

      assert :ok = AlertEngineWorker.perform(%{})

      alerts = Platform.list_alerts()
      matching = Enum.filter(alerts, fn a -> a.alert_rule_id == rule.id end)
      assert length(matching) >= 1

      alert = hd(matching)
      assert alert.severity == "critical"
      assert String.contains?(alert.message, "Low NAV Alert")
    end

    test "worker skips rules in cooldown" do
      five_min_ago = DateTime.utc_now() |> DateTime.add(-5 * 60, :second) |> DateTime.truncate(:second)

      rule =
        alert_rule_fixture(%{
          name: "Cooldown Test",
          metric: "nav",
          condition: "below",
          threshold: 999_999_999.0,
          cooldown_minutes: 60,
          is_active: true
        })

      # Set last_triggered_at to 5 minutes ago (within 60 min cooldown)
      {:ok, _} = Platform.update_alert_rule(rule, %{last_triggered_at: five_min_ago})

      assert :ok = AlertEngineWorker.perform(%{})

      # No alert should be created for this rule since it's in cooldown
      alerts = Platform.list_alerts()
      matching = Enum.filter(alerts, fn a -> a.alert_rule_id == rule.id end)
      assert matching == []
    end

    test "worker updates last_triggered_at when alert fires" do
      rule =
        alert_rule_fixture(%{
          name: "Trigger Time Test",
          metric: "nav",
          condition: "below",
          threshold: 999_999_999.0,
          is_active: true
        })

      assert rule.last_triggered_at == nil

      assert :ok = AlertEngineWorker.perform(%{})

      updated_rule = Platform.get_alert_rule!(rule.id)
      assert updated_rule.last_triggered_at != nil
    end
  end
end
