defmodule HoldcoWeb.ReportsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "reports page renders all report cards" do
    test "renders page title and description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Reports"
      assert html =~ "Generate printable reports"
    end

    test "renders all four report types", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Portfolio NAV Report"
      assert html =~ "Financial Summary Report"
      assert html =~ "Compliance Status Report"
      assert html =~ "Audit Package"
    end

    test "report cards contain Generate Report links with correct paths", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ ~s|href="/reports/portfolio"|
      assert html =~ ~s|href="/reports/financial"|
      assert html =~ ~s|href="/reports/compliance"|
    end

    test "audit package has download link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ ~s|href="/export/audit-package.zip"|
      assert html =~ "Download Package"
    end

    test "report cards contain Save as PDF buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Save as PDF"
    end

    test "report cards list included sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      # Portfolio NAV report includes
      assert html =~ "NAV breakdown"
      assert html =~ "Asset allocation"
      assert html =~ "FX exposure"

      # Financial Summary includes
      assert html =~ "Consolidated revenue"
      assert html =~ "P&amp;L by company"

      # Compliance includes
      assert html =~ "Tax deadlines"
      assert html =~ "Insurance policy"
    end
  end

  describe "scheduled reports section" do
    test "shows empty state when no active scheduled reports exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "No active scheduled reports"
      assert html =~ "Configure one"
    end

    test "shows scheduled reports table when active reports exist", %{conn: conn} do
      company = company_fixture()

      scheduled_report_fixture(%{
        company: company,
        name: "Weekly Portfolio Summary",
        report_type: "portfolio_summary",
        frequency: "weekly",
        is_active: true,
        next_run_date: "2026-03-10"
      })

      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Scheduled Reports"
      assert html =~ "Weekly Portfolio Summary"
      assert html =~ "portfolio_summary"
      assert html =~ "weekly"
      assert html =~ "2026-03-10"
    end

    test "only shows active scheduled reports", %{conn: conn} do
      company = company_fixture()

      scheduled_report_fixture(%{
        company: company,
        name: "ActiveReport",
        is_active: true,
        next_run_date: "2026-03-10"
      })

      scheduled_report_fixture(%{
        company: company,
        name: "InactiveReport",
        is_active: false,
        next_run_date: "2026-03-15"
      })

      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "ActiveReport"
      refute html =~ "InactiveReport"
    end

    test "scheduled reports table has correct column headers", %{conn: conn} do
      company = company_fixture()
      scheduled_report_fixture(%{company: company, is_active: true, next_run_date: "2026-03-10"})

      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "<th>Name</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Frequency</th>"
      assert html =~ "<th>Next Run</th>"
    end

    test "view all link navigates to scheduled reports page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ ~s|href="/scheduled-reports"|
      assert html =~ "View All"
    end
  end

  describe "print_page event" do
    test "print_page event pushes js-print and page still renders", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports")

      render_hook(view, "print_page", %{})

      html = render(view)
      assert html =~ "Reports"
      assert html =~ "Portfolio NAV Report"
    end
  end
end
