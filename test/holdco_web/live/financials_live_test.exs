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

    test "financials nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "more-active"
    end
  end
end
