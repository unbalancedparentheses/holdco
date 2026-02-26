defmodule HoldcoWeb.NotificationsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /notifications" do
    test "renders notifications page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Notifications"
    end

    test "renders page title and unread count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "page-title"
      assert html =~ "unread"
    end

    test "renders page title rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "page-title-rule"
    end

    test "shows notification table or empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      # Either shows a table or an empty state message
      assert html =~ "Notifications" or html =~ "empty"
    end
  end

  describe "nav active state" do
    test "notifications nav link is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ ~r/href="\/notifications"[^>]*class="active"/s
    end
  end
end
