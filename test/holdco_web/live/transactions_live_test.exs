defmodule HoldcoWeb.TransactionsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /transactions" do
    test "renders transactions page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Transactions"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "page-title"
      assert html =~ "transactions across all entities"
    end

    test "renders metrics strip with inflows and outflows", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "metrics-strip"
      assert html =~ "Total Inflows"
      assert html =~ "Total Outflows"
    end

    test "transactions nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ ~r/href="\/transactions"[^>]*class="active"/s
    end

    test "shows export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Export CSV"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Add Transaction"
    end
  end
end
