defmodule HoldcoWeb.AuditLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /audit-log" do
    test "renders audit log page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "Audit Log"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "page-title"
    end

    test "shows filter controls", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/audit-log")

      assert html =~ "filter" or html =~ "Filter"
    end
  end
end
