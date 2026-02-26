defmodule HoldcoWeb.FinancialsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /financials" do
    test "renders financials page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Financials"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "page-title"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "metrics-strip"
    end

    test "financials page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      # Financials is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Financials"
    end
  end
end
