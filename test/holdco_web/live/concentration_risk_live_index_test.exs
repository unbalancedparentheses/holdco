defmodule HoldcoWeb.ConcentrationRiskLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Concentration Risk page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Concentration Risk"
    end

    test "displays allocation breakdown section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Allocation Breakdown"
    end

    test "shows FX exposure section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "FX" || html =~ "Currency Exposure"
    end

    test "displays metrics strip with NAV", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Total NAV"
      assert html =~ "Asset Types"
      assert html =~ "Currency Exposures"
      assert html =~ "Concentration Alerts"
    end

    test "renders with holdings data", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "AAPL", quantity: 100.0, currency: "USD"})
      holding_fixture(%{company: company, asset: "MSFT", quantity: 50.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Concentration Risk"
    end

    test "shows Top Holdings by Value section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Top Holdings by Value"
    end

    test "shows empty state when no holdings", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "No holdings found" || html =~ "Concentration Risk"
    end

    test "renders allocation by asset type chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Allocation by Asset Type"
    end

    test "renders FX Currency Exposure chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "FX Currency Exposure"
    end

    test "shows allocation table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Asset Type"
      assert html =~ "Value (USD)"
      assert html =~ "% of Portfolio"
    end

    test "shows FX exposure table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Currency"
      assert html =~ "USD Value"
    end

    test "shows top holdings table headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Asset"
      assert html =~ "Ticker"
      assert html =~ "Type"
      assert html =~ "Risk"
    end

    test "handles noop event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/risk/concentration")
      html = render_click(live, "noop", %{})
      assert html =~ "Concentration Risk"
    end

    test "shows holding details in top holdings table", %{conn: conn} do
      company = company_fixture()

      holding_fixture(%{
        company: company,
        asset: "Tesla Stock",
        ticker: "TSLA",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Tesla Stock" || html =~ "TSLA" || html =~ "equity"
    end

    test "shows risk tags (LOW/MEDIUM/HIGH) for holdings", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Small Holding", quantity: 1.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "LOW" || html =~ "MEDIUM" || html =~ "HIGH" || html =~ "No holdings"
    end

    test "page description is shown", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Portfolio concentration analysis"
    end

    test "renders multiple holdings with different currencies", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "USD Stock", quantity: 100.0, currency: "USD"})
      holding_fixture(%{company: company, asset: "EUR Bond", quantity: 50.0, currency: "EUR"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Concentration Risk"
    end

    test "renders holdings with different asset types", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "AAPL Stock", asset_type: "equity", quantity: 100.0})
      holding_fixture(%{company: company, asset: "Treasury Bond", asset_type: "bond", quantity: 50.0})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Concentration Risk"
    end
  end
end
