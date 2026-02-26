defmodule HoldcoWeb.DashboardLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /" do
    test "renders dashboard page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Portfolio Overview"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "page-title"
      assert html =~ "Net Asset Value"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "metrics-strip"
      assert html =~ "metric-cell"
      assert html =~ "metric-label"
      assert html =~ "metric-value"
    end

    test "shows NAV metric", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "NAV"
    end

    test "overview nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~r/href="\/"[^>]*class="active"/
    end

    test "shows full navigation bar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "nav-links"
      assert html =~ "nav-utils"
    end

    test "shows footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "footer"
      assert html =~ "Holdco"
    end
  end
end
