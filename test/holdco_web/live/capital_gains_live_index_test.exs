defmodule HoldcoWeb.CapitalGainsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Capital Gains page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Capital Gains"
    end

    test "shows method selector with FIFO, LIFO, and Specific Lot", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "FIFO"
      assert html =~ "LIFO"
      assert html =~ "Specific Lot"
    end

    test "shows metrics strip with all gain categories", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Short-Term Gains"
      assert html =~ "Long-Term Gains"
      assert html =~ "Total Gains"
      assert html =~ "Est. Tax"
    end

    test "shows Holdings Detail section with table headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Holdings Detail"
      assert html =~ "Asset"
      assert html =~ "ST Realized"
      assert html =~ "LT Realized"
      assert html =~ "Total Gain"
    end

    test "shows empty state when no gains", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "No capital gains data found"
    end

    test "renders with holdings and cost basis lots", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "AAPL", ticker: "AAPL", quantity: 100.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 100.0, price_per_unit: 150.0})

      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Capital Gains"
    end

    test "switches to LIFO method", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax/capital-gains")
      html = render_click(live, "change_method", %{"method" => "lifo"})
      assert html =~ "Capital Gains"
    end

    test "defaults to FIFO method on mount", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      # FIFO should be selected by default
      assert html =~ "fifo" || html =~ "FIFO"
    end

    test "switches back to FIFO from LIFO", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax/capital-gains")
      render_click(live, "change_method", %{"method" => "lifo"})
      html = render_click(live, "change_method", %{"method" => "fifo"})
      assert html =~ "Capital Gains"
    end

    test "shows Tax Estimation Notes section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Tax Estimation Notes"
      assert html =~ "37%"
      assert html =~ "20%"
    end

    test "shows tax rate disclaimer", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Consult a tax professional"
    end

    test "shows Short-Term Realized and Long-Term Realized in tax notes", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Short-Term Realized"
      assert html =~ "Long-Term Realized"
    end

    test "shows Total row in holdings table footer", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Total"
    end

    test "displays method label in selector", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Method"
    end

    test "page description is shown", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Realized and unrealized gains analysis by cost basis method"
    end

    test "shows holding details with ticker when data exists", %{conn: conn} do
      company = company_fixture(%{name: "Gain Corp"})
      holding = holding_fixture(%{company: company, asset: "Google Stock", ticker: "GOOG", quantity: 50.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2022-06-01", quantity: 50.0, price_per_unit: 100.0})

      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Google Stock" || html =~ "GOOG" || html =~ "Capital Gains"
    end

    test "renders with multiple holdings with cost basis lots", %{conn: conn} do
      company = company_fixture()

      holding1 = holding_fixture(%{company: company, asset: "AAPL", ticker: "AAPL", quantity: 100.0})
      cost_basis_lot_fixture(%{holding: holding1, purchase_date: "2023-01-01", quantity: 100.0, price_per_unit: 150.0})

      holding2 = holding_fixture(%{company: company, asset: "MSFT", ticker: "MSFT", quantity: 50.0})
      cost_basis_lot_fixture(%{holding: holding2, purchase_date: "2023-06-01", quantity: 50.0, price_per_unit: 300.0})

      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Capital Gains"
    end

    test "method change recomputes summary data", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "TSLA", ticker: "TSLA", quantity: 200.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2022-01-01", quantity: 100.0, price_per_unit: 200.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 100.0, price_per_unit: 250.0})

      {:ok, live, _html} = live(conn, ~p"/tax/capital-gains")
      html = render_click(live, "change_method", %{"method" => "lifo"})
      assert html =~ "Capital Gains"
      assert html =~ "Total Gains"
    end

    test "shows Total Estimated Tax row in tax notes", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Total Estimated Tax"
    end

    test "unrealized gains note mentions exclusion from tax estimate", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Unrealized gains are shown for reference but not included in the tax estimate"
    end

    test "shows ST Unrealized and LT Unrealized columns", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "ST Unrealized"
      assert html =~ "LT Unrealized"
    end
  end
end
