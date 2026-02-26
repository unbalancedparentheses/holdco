defmodule HoldcoWeb.ReportsLiveTest do
  use HoldcoWeb.ConnCase

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
  end
end
