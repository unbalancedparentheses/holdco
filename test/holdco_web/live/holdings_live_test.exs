defmodule HoldcoWeb.HoldingsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /holdings" do
    test "renders holdings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Holdings"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "page-title"
      assert html =~ "positions across all entities"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "metrics-strip"
      assert html =~ "Total Positions"
    end

    test "holdings nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ ~r/href="\/holdings"[^>]*class="active"/s
    end

    test "shows export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Export CSV"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/holdings")

      assert html =~ "Add Holding"
    end
  end
end
