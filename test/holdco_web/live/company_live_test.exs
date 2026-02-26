defmodule HoldcoWeb.CompanyLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /companies" do
    test "renders companies index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Companies"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "shows view toggle buttons (list/tree)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "view-toggle"
    end

    test "companies nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ ~r/href="\/companies"[^>]*class="active"/s
    end
  end

  describe "company show page with tabs" do
    setup %{conn: conn} do
      # Create a company to visit its show page
      {:ok, company} = Holdco.Corporate.create_company(%{
        name: "Test Corp",
        jurisdiction: "US",
        entity_type: "LLC",
        status: "active",
        country: "US"
      })

      %{company: company, conn: conn}
    end

    test "renders company show page", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ company.name
    end

    test "renders all nine tabs", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ ~s(class="tabs")
      assert html =~ "Overview"
      assert html =~ "Holdings"
      assert html =~ "Bank Accounts"
      assert html =~ "Transactions"
      assert html =~ "Documents"
      assert html =~ "Governance"
      assert html =~ "Compliance"
      assert html =~ "Financials"
      assert html =~ "Comments"
    end

    test "overview tab is active by default", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="overview"/s
    end

    test "clicking holdings tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="holdings"/s
    end

    test "clicking comments tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="comments"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="comments"/s
    end

    test "clicking governance tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="governance"/s
    end

    test "clicking compliance tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="compliance"/s
    end

    test "clicking financials tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="financials"/s
    end
  end
end
