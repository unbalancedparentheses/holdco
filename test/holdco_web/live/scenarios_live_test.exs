defmodule HoldcoWeb.ScenariosLiveTest do
  use HoldcoWeb.ConnCase

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

    test "scenarios nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/scenarios")

      assert html =~ "more-active"
    end
  end
end
