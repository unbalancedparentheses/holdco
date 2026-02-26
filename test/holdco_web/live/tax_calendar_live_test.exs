defmodule HoldcoWeb.TaxCalendarLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /tax-calendar" do
    test "renders tax calendar page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Tax Calendar"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "page-title"
      assert html =~ "Tax deadlines"
    end

    test "renders metrics", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "metrics-strip" or html =~ "metric-cell"
    end

    test "tax calendar page loads", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/tax-calendar")

      assert html =~ "Tax Calendar"
    end
  end
end
