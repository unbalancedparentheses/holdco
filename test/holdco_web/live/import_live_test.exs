defmodule HoldcoWeb.ImportLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /import" do
    test "renders import page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Import CSV"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "page-title"
    end

    test "shows tab buttons for import types", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "companies" or html =~ "Companies"
      assert html =~ "holdings" or html =~ "Holdings"
      assert html =~ "transactions" or html =~ "Transactions"
    end
  end
end
