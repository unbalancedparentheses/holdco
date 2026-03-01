defmodule HoldcoWeb.ReportsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /reports" do
    test "renders reports page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Reports"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "page-title"
      assert html =~ "Generate printable reports"
    end

    test "shows report cards", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Portfolio NAV"
      assert html =~ "Financial Summary"
      assert html =~ "Compliance Status"
    end

    test "reports nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ ~r/href="\/reports"[^>]*class="active"/s
    end

    test "uses panel and grid classes", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "grid-3"
      assert html =~ "panel"
    end

    test "shows Save as PDF buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Save as PDF"
    end

    test "shows Generate Report links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Generate Report"
      assert html =~ "/reports/portfolio"
      assert html =~ "/reports/financial"
      assert html =~ "/reports/compliance"
    end

    test "shows Audit Package card", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Audit Package"
      assert html =~ "Download Package"
    end

    test "shows print instructions in footer section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/reports")

      assert html =~ "Reports open in a new tab"
      assert html =~ "print dialog"
    end

    test "print_page event pushes js-print event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/reports")

      # The print_page event pushes a JS event - should not crash
      render_hook(view, "print_page", %{})
      assert render(view) =~ "Reports"
    end
  end
end
