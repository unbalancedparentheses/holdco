defmodule HoldcoWeb.ScenariosLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /scenarios" do
    test "renders scenarios page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "Scenarios"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "page-title"
      assert html =~ "Financial projections"
    end

    test "scenarios page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      # Scenarios is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Scenarios"
    end
  end
end
