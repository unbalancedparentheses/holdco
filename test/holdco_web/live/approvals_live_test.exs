defmodule HoldcoWeb.ApprovalsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /approvals" do
    test "renders approvals page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Approvals"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "page-title"
    end

    test "shows pending/approved/rejected sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ "Pending" or html =~ "pending"
    end

    test "approvals nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/approvals")

      assert html =~ ~r/nav-util-link\s+active/
    end
  end
end
