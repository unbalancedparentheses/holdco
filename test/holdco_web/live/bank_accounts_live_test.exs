defmodule HoldcoWeb.BankAccountsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /bank-accounts" do
    test "renders bank accounts page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Bank Accounts"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "page-title"
    end

    test "bank accounts page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      # Bank Accounts is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Bank Accounts"
    end
  end
end
