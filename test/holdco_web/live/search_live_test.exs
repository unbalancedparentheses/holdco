defmodule HoldcoWeb.SearchLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /search" do
    test "renders search page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "Search"
    end

    test "renders search input", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "form-input" or html =~ ~s(type="text")
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search")

      assert html =~ "page-title"
    end
  end

  describe "search with query" do
    test "renders search results page with query", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/search?q=test")

      assert html =~ "Search"
    end
  end
end
