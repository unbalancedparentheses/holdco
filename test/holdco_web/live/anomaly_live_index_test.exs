defmodule HoldcoWeb.AnomalyLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Anomaly Detection page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Anomaly Detection"
      assert html =~ "Automated detection of unusual patterns"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Open Anomalies"
      assert html =~ "Critical"
      assert html =~ "Investigating"
      assert html =~ "Resolved This Month"
    end

    test "shows filter section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Filter"
      assert html =~ "Status"
      assert html =~ "Severity"
      assert html =~ "Anomaly Type"
      assert html =~ "Entity Type"
    end

    test "shows anomalies table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Description"
      assert html =~ "Entity"
      assert html =~ "Deviation %"
    end

    test "shows empty state when no anomalies", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "No anomalies found"
    end

    test "shows Run Detection button", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Run Detection"
    end
  end

  describe "anomaly data display" do
    test "displays anomaly in the table", %{conn: conn} do
      anomaly = anomaly_fixture(%{description: "Suspicious transfer detected", severity: "high", status: "open"})

      {:ok, _live, html} = live(conn, ~p"/anomalies")
      assert html =~ "Suspicious transfer detected"
      assert html =~ "high"
      assert html =~ "open"
      assert html =~ to_string(anomaly.entity_type)
    end
  end

  describe "filter event" do
    test "filters anomalies by status", %{conn: conn} do
      anomaly_fixture(%{status: "open", description: "Open anomaly"})
      anomaly_fixture(%{status: "investigating", description: "Investigating anomaly"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")

      html = render_change(view, "filter", %{"status" => "open", "severity" => "", "anomaly_type" => "", "entity_type" => ""})
      assert html =~ "Open anomaly"
    end

    test "filters anomalies by severity", %{conn: conn} do
      anomaly_fixture(%{severity: "critical", description: "Critical issue"})
      anomaly_fixture(%{severity: "low", description: "Minor issue"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")

      html = render_change(view, "filter", %{"status" => "", "severity" => "critical", "anomaly_type" => "", "entity_type" => ""})
      assert html =~ "Critical issue"
    end

    test "filters anomalies by anomaly_type", %{conn: conn} do
      anomaly_fixture(%{anomaly_type: "duplicate", description: "Dup found"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")

      html = render_change(view, "filter", %{"status" => "", "severity" => "", "anomaly_type" => "duplicate", "entity_type" => ""})
      assert html =~ "Dup found"
    end

    test "filters anomalies by entity_type", %{conn: conn} do
      anomaly_fixture(%{entity_type: "financial", description: "Financial anomaly"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")

      html = render_change(view, "filter", %{"status" => "", "severity" => "", "anomaly_type" => "", "entity_type" => "financial"})
      assert html =~ "Financial anomaly"
    end
  end

  describe "run_detection event" do
    test "runs anomaly detection and shows flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/anomalies")
      html = render_click(view, "run_detection", %{})
      assert html =~ "Anomaly detection completed"
    end
  end

  describe "investigate event" do
    test "marks anomaly as investigating", %{conn: conn} do
      anomaly = anomaly_fixture(%{status: "open", description: "Investigate me"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")
      html = render_click(view, "investigate", %{"id" => to_string(anomaly.id)})
      assert html =~ "Anomaly marked as investigating"
    end
  end

  describe "show_notes and close_notes events" do
    test "opens resolve notes modal", %{conn: conn} do
      anomaly = anomaly_fixture(%{status: "open", description: "Notes anomaly"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")
      html = render_click(view, "show_notes", %{"id" => to_string(anomaly.id)})
      assert html =~ "Resolve Anomaly"
      assert html =~ "Notes"
      assert html =~ "False Positive"
    end

    test "closes resolve notes modal", %{conn: conn} do
      anomaly = anomaly_fixture(%{status: "open", description: "Close notes test"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")
      render_click(view, "show_notes", %{"id" => to_string(anomaly.id)})
      html = render_click(view, "close_notes", %{})
      refute html =~ "Resolve Anomaly"
    end
  end

  describe "resolve event" do
    test "resolves an anomaly", %{conn: conn} do
      anomaly = anomaly_fixture(%{status: "investigating", description: "Resolve me"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")
      html = render_click(view, "resolve", %{"id" => to_string(anomaly.id), "notes" => "Fixed the issue"})
      assert html =~ "Anomaly resolved"
    end
  end

  describe "mark_false_positive event" do
    test "marks an anomaly as false positive", %{conn: conn} do
      anomaly = anomaly_fixture(%{status: "investigating", description: "False pos test"})

      {:ok, view, _html} = live(conn, ~p"/anomalies")
      html = render_click(view, "mark_false_positive", %{"id" => to_string(anomaly.id), "notes" => "Not a real anomaly"})
      assert html =~ "Anomaly marked as false positive"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, html_before} = live(conn, ~p"/anomalies")
      html_after = render_click(view, "noop", %{})
      assert html_after =~ "Anomaly Detection"
      assert html_before =~ "Anomaly Detection"
    end
  end
end
