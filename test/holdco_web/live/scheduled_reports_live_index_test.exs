defmodule HoldcoWeb.ScheduledReportsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "show_form and close_form" do
    test "show_form opens the new report dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "show_form")
      assert html =~ "New Scheduled Report"
      assert html =~ "Name *"
      assert html =~ "Report Type *"
      assert html =~ "Frequency *"
      assert html =~ "Recipients *"
    end

    test "close_form hides the dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "save_report (create)" do
    test "creating a scheduled report with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      render_click(view, "show_form")

      html =
        render_click(view, "save_report", %{
          "report" => %{
            "name" => "My Weekly Report",
            "report_type" => "portfolio_summary",
            "frequency" => "weekly",
            "recipients" => "alice@example.com",
            "format" => "html"
          }
        })

      assert html =~ "Scheduled report created"
      assert html =~ "My Weekly Report"
    end

    test "creating a report with missing required fields shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      render_click(view, "show_form")

      html =
        render_click(view, "save_report", %{
          "report" => %{
            "name" => "",
            "report_type" => "",
            "frequency" => "",
            "recipients" => ""
          }
        })

      assert html =~ "Failed to create report"
    end
  end

  describe "edit and save_report (update)" do
    test "edit event opens edit form with existing data", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Editable Report"})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "edit", %{"id" => to_string(report.id)})
      assert html =~ "Edit Report"
      assert html =~ "Editable Report"
    end

    test "updating a report with valid data", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Old Report Name"})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      render_click(view, "edit", %{"id" => to_string(report.id)})

      html =
        render_click(view, "save_report", %{
          "report" => %{
            "name" => "Updated Report Name",
            "report_type" => "financial_report",
            "frequency" => "monthly",
            "recipients" => "bob@example.com",
            "format" => "csv"
          }
        })

      assert html =~ "Scheduled report updated"
      assert html =~ "Updated Report Name"
    end
  end

  describe "delete" do
    test "deleting a scheduled report removes it", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Doomed Report"})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      assert render(view) =~ "Doomed Report"

      html = render_click(view, "delete", %{"id" => to_string(report.id)})
      assert html =~ "Report deleted"
      refute html =~ "Doomed Report"
    end
  end

  describe "toggle_active" do
    test "toggling active pauses an active report", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Toggle Report", is_active: true})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "toggle_active", %{"id" => to_string(report.id)})
      assert html =~ "Report paused"
    end

    test "toggling active activates a paused report", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Paused Report", is_active: false})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "toggle_active", %{"id" => to_string(report.id)})
      assert html =~ "Report activated"
    end
  end

  describe "send_now" do
    test "send_now queues report for immediate delivery", %{conn: conn} do
      report = scheduled_report_fixture(%{name: "Urgent Report"})

      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "send_now", %{"id" => to_string(report.id)})
      assert html =~ "queued for immediate delivery"
    end
  end

  describe "noop" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")
      html = render_click(view, "noop")
      assert html =~ "Scheduled Reports"
    end
  end

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/scheduled-reports")

      scheduled_report_fixture(%{name: "PubSub Report"})

      send(view.pid, {:analytics_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Report"
    end
  end
end
