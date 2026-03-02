defmodule HoldcoWeb.ConcentrationRiskLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
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

    test "renders with single holding that dominates portfolio", %{conn: conn} do
      company = company_fixture()
      # Create one holding with high value
      holding_fixture(%{
        company: company,
        asset: "Mega Corp",
        ticker: "MEGA",
        asset_type: "equity",
        quantity: 10000.0,
        currency: "USD"
      })

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "Mega Corp"
      assert html =~ "MEGA"
    end

    test "shows concentration alerts when a holding exceeds 25% threshold", %{conn: conn} do
      company = company_fixture()

      # Create single dominant holding with price data
      holding_fixture(%{
        company: company,
        asset: "Dominant Stock",
        ticker: "DOM",
        asset_type: "equity",
        quantity: 1000.0,
        currency: "USD"
      })

      # Record price for DOM ticker
      price_history_fixture(%{ticker: "DOM", price: 100.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      # With only one holding, it will be 100% of portfolio - triggers alert
      assert html =~ "ALERT"
      assert html =~ "Dominant Stock"
      assert html =~ "exceeds"
      assert html =~ "HIGH"
    end

    test "shows MEDIUM risk tag for holding between 15-25% of NAV", %{conn: conn} do
      company = company_fixture()

      # Create 5 holdings to spread the portfolio
      # MED1 = 200*10 = 2000 (20% of 10000) -> MEDIUM
      # Others = 2000 each (20% each) -> all MEDIUM
      holding_fixture(%{
        company: company,
        asset: "Medium Stock",
        ticker: "MEDT",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      holding_fixture(%{
        company: company,
        asset: "Stock B",
        ticker: "MEDB",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      holding_fixture(%{
        company: company,
        asset: "Stock C",
        ticker: "MEDC",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      holding_fixture(%{
        company: company,
        asset: "Stock D",
        ticker: "MEDD",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      holding_fixture(%{
        company: company,
        asset: "Stock E",
        ticker: "MEDE",
        asset_type: "equity",
        quantity: 200.0,
        currency: "USD"
      })

      # Each holding = 200*10 = 2000, total = 10000, each = 20% -> MEDIUM (>15% but <25%)
      price_history_fixture(%{ticker: "MEDT", price: 10.0, currency: "USD"})
      price_history_fixture(%{ticker: "MEDB", price: 10.0, currency: "USD"})
      price_history_fixture(%{ticker: "MEDC", price: 10.0, currency: "USD"})
      price_history_fixture(%{ticker: "MEDD", price: 10.0, currency: "USD"})
      price_history_fixture(%{ticker: "MEDE", price: 10.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "MEDIUM"
    end

    test "shows LOW risk tag for small holding", %{conn: conn} do
      company = company_fixture()

      # Create a small holding and a large one
      holding_fixture(%{
        company: company,
        asset: "Small Stock",
        ticker: "SML",
        asset_type: "equity",
        quantity: 10.0,
        currency: "USD"
      })

      holding_fixture(%{
        company: company,
        asset: "Big Stock",
        ticker: "BIG",
        asset_type: "equity",
        quantity: 990.0,
        currency: "USD"
      })

      price_history_fixture(%{ticker: "SML", price: 1.0, currency: "USD"})
      price_history_fixture(%{ticker: "BIG", price: 1.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      assert html =~ "LOW"
    end

    test "no concentration alerts when total portfolio is zero", %{conn: conn} do
      # No holdings at all -> total_portfolio = 0 -> build_alerts catch-all returns []
      {:ok, _live, html} = live(conn, ~p"/risk/concentration")
      refute html =~ "ALERT"
      assert html =~ "No holdings found"
    end
  end
end
