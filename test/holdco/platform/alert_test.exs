defmodule Holdco.Platform.AlertTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Platform

  describe "create_alert/1" do
    test "creates alert with valid attrs" do
      rule = alert_rule_fixture()

      assert {:ok, alert} =
               Platform.create_alert(%{
                 alert_rule_id: rule.id,
                 message: "NAV dropped below threshold",
                 severity: "warning",
                 metric_value: Decimal.new("800000"),
                 threshold_value: Decimal.new("1000000")
               })

      assert alert.alert_rule_id == rule.id
      assert alert.message == "NAV dropped below threshold"
      assert alert.severity == "warning"
      assert alert.status == "unread"
      assert Decimal.equal?(alert.metric_value, Decimal.new("800000"))
    end

    test "validates required fields" do
      assert {:error, changeset} = Platform.create_alert(%{})
      errors = errors_on(changeset)
      assert errors[:alert_rule_id]
      assert errors[:message]
      assert errors[:severity]
    end

    test "validates severity inclusion" do
      rule = alert_rule_fixture()

      assert {:error, changeset} =
               Platform.create_alert(%{
                 alert_rule_id: rule.id,
                 message: "Test",
                 severity: "extreme"
               })

      assert "is invalid" in errors_on(changeset)[:severity]
    end

    test "validates status inclusion" do
      rule = alert_rule_fixture()

      assert {:error, changeset} =
               Platform.create_alert(%{
                 alert_rule_id: rule.id,
                 message: "Test",
                 severity: "warning",
                 status: "invalid_status"
               })

      assert "is invalid" in errors_on(changeset)[:status]
    end
  end

  describe "list_alerts/1" do
    test "returns all alerts" do
      rule = alert_rule_fixture()
      {:ok, a1} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Alert 1", severity: "warning"})
      {:ok, a2} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Alert 2", severity: "critical"})

      alerts = Platform.list_alerts()
      alert_ids = Enum.map(alerts, & &1.id)

      assert a1.id in alert_ids
      assert a2.id in alert_ids
    end

    test "filters by status" do
      rule = alert_rule_fixture()
      {:ok, _a1} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Unread", severity: "warning"})
      {:ok, a2} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Read", severity: "warning", status: "read"})

      alerts = Platform.list_alerts(status: "read")
      alert_ids = Enum.map(alerts, & &1.id)

      assert a2.id in alert_ids
      assert length(alerts) == 1
    end

    test "filters by severity" do
      rule = alert_rule_fixture()
      {:ok, _a1} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Warning", severity: "warning"})
      {:ok, a2} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Critical", severity: "critical"})

      alerts = Platform.list_alerts(severity: "critical")
      alert_ids = Enum.map(alerts, & &1.id)

      assert a2.id in alert_ids
      assert length(alerts) == 1
    end

    test "applies limit" do
      rule = alert_rule_fixture()
      {:ok, _a1} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Alert 1", severity: "warning"})
      {:ok, _a2} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Alert 2", severity: "warning"})
      {:ok, _a3} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Alert 3", severity: "warning"})

      alerts = Platform.list_alerts(limit: 2)
      assert length(alerts) == 2
    end
  end

  describe "count_unread_alerts/0" do
    test "counts unread alerts correctly" do
      rule = alert_rule_fixture()
      {:ok, _a1} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Unread 1", severity: "warning"})
      {:ok, _a2} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Unread 2", severity: "warning"})
      {:ok, _a3} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Read", severity: "warning", status: "read"})

      assert Platform.count_unread_alerts() == 2
    end

    test "returns 0 when no unread alerts" do
      assert Platform.count_unread_alerts() == 0
    end
  end

  describe "acknowledge_alert/2" do
    test "sets status and timestamp" do
      rule = alert_rule_fixture()
      {:ok, alert} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Test", severity: "warning"})
      user = user_fixture()

      assert {:ok, acked} = Platform.acknowledge_alert(alert, user.id)
      assert acked.status == "acknowledged"
      assert acked.acknowledged_by_id == user.id
      assert acked.acknowledged_at != nil
    end
  end

  describe "resolve_alert/1" do
    test "sets status and resolved_at" do
      rule = alert_rule_fixture()
      {:ok, alert} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Test", severity: "warning"})

      assert {:ok, resolved} = Platform.resolve_alert(alert)
      assert resolved.status == "resolved"
      assert resolved.resolved_at != nil
    end
  end

  describe "mark_alert_read/1" do
    test "changes status to read" do
      rule = alert_rule_fixture()
      {:ok, alert} = Platform.create_alert(%{alert_rule_id: rule.id, message: "Test", severity: "warning"})

      assert alert.status == "unread"
      assert {:ok, read} = Platform.mark_alert_read(alert)
      assert read.status == "read"
    end
  end
end
