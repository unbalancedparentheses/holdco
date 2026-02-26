defmodule HoldcoWeb.ComplianceLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /compliance" do
    test "renders compliance page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "Compliance"
    end

    test "renders page title with rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders tabs container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~s(class="tabs")
    end

    test "renders all seven compliance tabs", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~s(phx-value-tab="regulatory_filings")
      assert html =~ ~s(phx-value-tab="licenses")
      assert html =~ ~s(phx-value-tab="insurance")
      assert html =~ ~s(phx-value-tab="sanctions")
      assert html =~ ~s(phx-value-tab="esg")
      assert html =~ ~s(phx-value-tab="fatca")
      assert html =~ ~s(phx-value-tab="withholding")
    end

    test "regulatory_filings tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="regulatory_filings"/s
    end

    test "renders tab-content wrapper", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ "tab-content"
    end
  end

  describe "tab switching" do
    test "clicking licenses tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="licenses"/s
      assert html =~ ~r/class="tab "[^>]*phx-value-tab="regulatory_filings"/s
    end

    test "clicking insurance tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="insurance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="insurance"/s
    end

    test "clicking sanctions tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="sanctions"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="sanctions"/s
    end

    test "clicking esg tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="esg"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="esg"/s
    end

    test "clicking fatca tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="fatca"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="fatca"/s
    end

    test "clicking withholding tab activates it", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/compliance")

      html = view |> element(~s(button[phx-value-tab="withholding"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="withholding"/s
    end

    test "switching tabs closes form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/compliance")

      view |> element("button", "Add") |> render_click()

      html = view |> element(~s(button[phx-value-tab="licenses"])) |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  describe "nav active state" do
    test "compliance nav link is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/compliance")

      assert html =~ ~r/href="\/compliance"[^>]*class="active"/s
    end
  end
end
