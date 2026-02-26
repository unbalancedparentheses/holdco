defmodule HoldcoWeb.LayoutAndNavTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "unauthenticated layout (login page)" do
    test "login page does not show nav links", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      # Nav bar exists but should NOT have nav-links when logged out
      refute html =~ ~s(class="nav-links")
      refute html =~ ~s(>Overview</a>)
      refute html =~ ~s(>Holdings</a>)
      refute html =~ ~s(>Governance</a>)
      refute html =~ ~s(>Compliance</a>)
      refute html =~ "nav-utils"
      refute html =~ "nav-search"
      refute html =~ "nav-user"
    end

    test "login page shows auth brand", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ "auth-brand"
      assert html =~ "Holdco"
      refute html =~ "masthead"
      refute html =~ "nav-brand"
    end

    test "login page renders auth-card", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ "auth-card"
      assert html =~ "Log in"
    end

    test "login page uses flash-info instead of alert-info for mail adapter notice", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      refute html =~ "alert alert-info"
      refute html =~ "alert-info"
    end

    test "login page uses auth-divider instead of daisyUI divider", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ "auth-divider"
      refute html =~ ~r/class="divider"/
    end

    test "login page has email and password forms", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ "login_form_magic"
      assert html =~ "login_form_password"
      assert html =~ "Log in with email"
      assert html =~ "Log in and stay logged in"
    end

    test "login page links to registration", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert html =~ ~p"/users/register"
      assert html =~ "Sign up"
    end
  end

  describe "unauthenticated layout (registration page)" do
    test "registration page does not show nav links", %{conn: conn} do
      html = conn |> get(~p"/users/register") |> html_response(200)

      refute html =~ ~s(class="nav-links")
      refute html =~ "nav-utils"
      refute html =~ "nav-search"
    end

    test "registration page shows auth brand", %{conn: conn} do
      html = conn |> get(~p"/users/register") |> html_response(200)

      assert html =~ "auth-brand"
      assert html =~ "Holdco"
      refute html =~ "masthead"
      refute html =~ "nav-brand"
    end

    test "registration page renders auth-card", %{conn: conn} do
      html = conn |> get(~p"/users/register") |> html_response(200)

      assert html =~ "auth-card"
      assert html =~ "Create an account"
    end

    test "registration page has email form", %{conn: conn} do
      html = conn |> get(~p"/users/register") |> html_response(200)

      assert html =~ "Create an account"
      assert html =~ ~s(type="email")
    end

    test "registration page links to login", %{conn: conn} do
      html = conn |> get(~p"/users/register") |> html_response(200)

      assert html =~ ~p"/users/log-in"
      assert html =~ "Log in"
    end
  end

  describe "authenticated layout (nav bar)" do
    setup :register_and_log_in_user

    test "shows nav-links when logged in", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "nav-links"
    end

    test "shows all navigation links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Overview"
      assert html =~ ~p"/companies"
      # Accounting dropdown
      assert html =~ "Accounting"
      assert html =~ "Chart of Accounts"
      assert html =~ "Journal Entries"
      # Tax Calendar (top-level)
      assert html =~ "Tax Calendar"
      # Approvals and Notifications in nav-utils
      assert html =~ "Approvals"
      assert html =~ "Notifications"
      # Direct links
      assert html =~ "Reports"
      assert html =~ "Settings"
    end

    test "shows nav-utils with search and user info", %{conn: conn, user: user} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "nav-utils"
      assert html =~ "nav-search"
      assert html =~ ~s(placeholder="Search...")
      assert html =~ "nav-user"
      assert html =~ user.email
      assert html =~ "Logout"
    end

    test "search form uses nav-search class instead of inline styles", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "nav-search"
      # Should not have inline styles on the search form
      refute html =~ ~s(style="display: inline-flex; align-items: center; margin-left: 0.5rem;")
    end

    test "shows masthead with date and branding", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "masthead"
      assert html =~ "Portfolio Management"
      assert html =~ "masthead-title"
    end

    test "shows footer with audit log and settings links", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "footer"
      assert html =~ "Audit Log"
      assert html =~ ~p"/audit-log"
      assert html =~ ~p"/settings"
    end

    test "active nav link is highlighted on dashboard", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      # The dashboard link should have the active class
      assert html =~ ~r/href="\/"[^>]*class="active"/
    end
  end
end
