defmodule HoldcoWeb.SettingsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /settings" do
    test "renders settings page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "page-title"
    end

    test "renders tabs container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ ~s(class="tabs")
    end

    test "renders all four settings tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ ~s(phx-value-tab="settings")
      assert html =~ ~s(phx-value-tab="categories")
      assert html =~ ~s(phx-value-tab="webhooks")
      assert html =~ ~s(phx-value-tab="backups")
    end

    test "settings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="settings"/s
    end

    test "renders tab-content wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "tab-content"
    end
  end

  describe "tab switching" do
    test "clicking categories tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="categories"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="categories"/s
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="settings"/s
    end

    test "clicking webhooks tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="webhooks"/s
    end

    test "clicking backups tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="backups"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="backups"/s
    end

    test "switching tabs closes form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element("button", "Add") |> render_click()

      html = view |> element(~s(button[phx-value-tab="categories"])) |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  describe "nav active state" do
    test "settings nav link is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ ~r/href="\/settings"[^>]*class="active"/s
    end
  end
end
