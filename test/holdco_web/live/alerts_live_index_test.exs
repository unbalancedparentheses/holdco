defmodule HoldcoWeb.AlertsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "opens new rule form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/alerts")
      html = render_click(live, "show_form")
      assert html =~ "New Alert Rule"
      assert html =~ "Create Rule"
    end

    test "switches to alerts tab", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/alerts")
      html = render_click(live, "switch_tab", %{"tab" => "alerts"})
      assert html =~ "No alerts match the current filters"
    end
  end

  describe "close_form" do
    test "closes the new rule form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "New Alert Rule"
    end
  end

  describe "save_rule (create)" do
    test "creates a new alert rule with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "show_form")

      html =
        render_click(view, "save_rule", %{
          "alert_rule" => %{
            "name" => "NAV Below 1M",
            "metric" => "nav",
            "condition" => "below",
            "threshold" => "1000000",
            "severity" => "critical",
            "cooldown_minutes" => "60"
          }
        })

      assert html =~ "Alert rule created successfully"
      assert html =~ "NAV Below 1M"
    end

    test "shows error when saving with missing required fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "show_form")

      html =
        render_click(view, "save_rule", %{
          "alert_rule" => %{
            "name" => "",
            "metric" => "",
            "condition" => "",
            "threshold" => ""
          }
        })

      assert html =~ "Failed to save alert rule"
    end
  end

  describe "save_rule (update)" do
    test "updates an existing alert rule", %{conn: conn} do
      rule = alert_rule_fixture(%{name: "Old Rule Name"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "edit_rule", %{"id" => to_string(rule.id)})

      html =
        render_click(view, "save_rule", %{
          "alert_rule" => %{
            "name" => "Updated Rule Name",
            "metric" => "nav",
            "condition" => "above",
            "threshold" => "2000000",
            "severity" => "info",
            "cooldown_minutes" => "120"
          }
        })

      assert html =~ "Alert rule updated successfully"
      assert html =~ "Updated Rule Name"
    end
  end

  describe "edit_rule" do
    test "opens form in edit mode for an existing rule", %{conn: conn} do
      rule = alert_rule_fixture(%{name: "My Test Rule"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      html = render_click(view, "edit_rule", %{"id" => to_string(rule.id)})

      assert html =~ "Edit Alert Rule"
      assert html =~ "Update Rule"
    end
  end

  describe "delete_rule" do
    test "deletes an alert rule", %{conn: conn} do
      rule = alert_rule_fixture(%{name: "Rule To Delete"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      assert render(view) =~ "Rule To Delete"

      html = render_click(view, "delete_rule", %{"id" => to_string(rule.id)})
      assert html =~ "Alert rule deleted"
      refute html =~ "Rule To Delete"
    end
  end

  describe "toggle_rule" do
    test "toggles an alert rule active/inactive", %{conn: conn} do
      rule = alert_rule_fixture(%{name: "Toggle Me", is_active: true})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      assert render(view) =~ "Active"

      render_click(view, "toggle_rule", %{"id" => to_string(rule.id)})
      html = render(view)
      assert html =~ "Toggle Me"
    end
  end

  describe "filter_status" do
    test "filters alerts by status", %{conn: conn} do
      rule = alert_rule_fixture()
      alert_fixture_for_rule(%{alert_rule: rule, message: "Unread alert message", status: "unread"})
      alert_fixture_for_rule(%{alert_rule: rule, message: "Read alert message", status: "read"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})

      html = render_click(view, "filter_status", %{"status" => "unread"})
      assert html =~ "Unread alert message"
      refute html =~ "Read alert message"
    end

    test "clears status filter with empty string shows all", %{conn: conn} do
      rule = alert_rule_fixture()
      alert_fixture_for_rule(%{alert_rule: rule, message: "Any status alert"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})
      render_click(view, "filter_status", %{"status" => "unread"})
      html = render_click(view, "filter_status", %{"status" => ""})
      assert html =~ "Any status alert"
    end
  end

  describe "filter_severity" do
    test "filters alerts by severity", %{conn: conn} do
      critical_rule = alert_rule_fixture(%{name: "Critical Rule", severity: "critical"})
      warning_rule = alert_rule_fixture(%{name: "Warning Rule", severity: "warning"})
      alert_fixture_for_rule(%{alert_rule: critical_rule, message: "Critical severity alert"})
      alert_fixture_for_rule(%{alert_rule: warning_rule, message: "Warning severity alert"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})

      html = render_click(view, "filter_severity", %{"severity" => "critical"})
      assert html =~ "Critical severity alert"
      refute html =~ "Warning severity alert"
    end

    test "clears severity filter with empty string shows all", %{conn: conn} do
      rule = alert_rule_fixture()
      alert_fixture_for_rule(%{alert_rule: rule, message: "All severity alert"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})
      render_click(view, "filter_severity", %{"severity" => "warning"})
      html = render_click(view, "filter_severity", %{"severity" => ""})
      assert html =~ "All severity alert"
    end
  end

  describe "alert actions" do
    test "acknowledges an alert changes its status", %{conn: conn} do
      rule = alert_rule_fixture()
      alert = alert_fixture_for_rule(%{alert_rule: rule, message: "Acknowledge me"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})
      assert render(view) =~ "Acknowledge me"

      html = render_click(view, "acknowledge_alert", %{"id" => to_string(alert.id)})
      assert html =~ "acknowledged"
    end

    test "resolves an alert changes its status", %{conn: conn} do
      rule = alert_rule_fixture()
      alert = alert_fixture_for_rule(%{alert_rule: rule, message: "Resolve me"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})
      assert render(view) =~ "Resolve me"

      html = render_click(view, "resolve_alert", %{"id" => to_string(alert.id)})
      assert html =~ "resolved"
    end

    test "marks an alert as read", %{conn: conn} do
      rule = alert_rule_fixture()
      alert = alert_fixture_for_rule(%{alert_rule: rule, message: "Mark me read"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      render_click(view, "switch_tab", %{"tab" => "alerts"})
      assert render(view) =~ "Mark me read"

      html = render_click(view, "mark_read", %{"id" => to_string(alert.id)})
      assert html =~ "Mark me read"
    end
  end

  describe "displays existing data" do
    test "shows alert rule in table", %{conn: conn} do
      alert_rule_fixture(%{name: "Portfolio NAV Alert", metric: "nav", severity: "critical"})

      {:ok, _view, html} = live(conn, ~p"/alerts")
      assert html =~ "Portfolio NAV Alert"
      assert html =~ "nav"
      assert html =~ "critical"
    end

    test "shows alert in alerts tab", %{conn: conn} do
      rule = alert_rule_fixture()
      alert_fixture_for_rule(%{alert_rule: rule, message: "NAV dropped below threshold"})

      {:ok, view, _html} = live(conn, ~p"/alerts")
      html = render_click(view, "switch_tab", %{"tab" => "alerts"})
      assert html =~ "NAV dropped below threshold"
    end
  end
end
