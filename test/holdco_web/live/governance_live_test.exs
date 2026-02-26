defmodule HoldcoWeb.GovernanceLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /governance" do
    test "renders governance page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "Governance"
      assert html =~ "Board meetings, cap table, resolutions"
    end

    test "renders page title and rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders tabs container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(class="tabs")
    end

    test "renders all seven governance tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ ~s(phx-value-tab="meetings")
      assert html =~ ~s(phx-value-tab="cap_table")
      assert html =~ ~s(phx-value-tab="resolutions")
      assert html =~ ~s(phx-value-tab="deals")
      assert html =~ ~s(phx-value-tab="equity_plans")
      assert html =~ ~s(phx-value-tab="joint_ventures")
      assert html =~ ~s(phx-value-tab="powers_of_attorney")
    end

    test "meetings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      # The first tab (meetings) should have tab-active class
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="meetings"/s
    end

    test "renders tab-content wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "tab-content"
    end

    test "other tabs are not active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      # cap_table tab should not have tab-active
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="cap_table"/s
    end
  end

  describe "tab switching" do
    test "clicking cap_table tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="cap_table"/s
      # meetings should no longer be active
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="meetings"/s
    end

    test "clicking resolutions tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="resolutions"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="resolutions"/s
    end

    test "clicking deals tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="deals"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="deals"/s
    end

    test "clicking equity_plans tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="equity_plans"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="equity_plans"/s
    end

    test "clicking joint_ventures tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="joint_ventures"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="joint_ventures"/s
    end

    test "clicking powers_of_attorney tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/governance")

      html = view |> element(~s(button[phx-value-tab="powers_of_attorney"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="powers_of_attorney"/s
    end

    test "switching tabs closes form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/governance")

      # Open form (only visible to editors)
      view |> element("button", "Add") |> render_click()

      # Switch tab — form should close
      html = view |> element(~s(button[phx-value-tab="cap_table"])) |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  describe "nav active state on governance page" do
    test "consolidated dropdown is highlighted when on governance", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/governance")

      assert html =~ "more-active"
    end
  end
end
