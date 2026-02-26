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

    test "bank accounts nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ ~r/href="\/bank-accounts"[^>]*class="active"/s
    end
  end
end
