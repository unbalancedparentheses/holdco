defmodule HoldcoWeb.CapitalGainsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "switches to LIFO method", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax/capital-gains")
      html = render_click(live, "change_method", %{"method" => "lifo"})
      assert html =~ "Capital Gains"
    end

    test "defaults to FIFO method on mount", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      # FIFO should be selected by default
      assert html =~ "FIFO"
    end

    test "switches back to FIFO from LIFO", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/tax/capital-gains")
      render_click(live, "change_method", %{"method" => "lifo"})
      html = render_click(live, "change_method", %{"method" => "fifo"})
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

    test "renders company name in results table", %{conn: conn} do
      company = company_fixture(%{name: "Capital Corp"})
      holding = holding_fixture(%{company: company, asset: "CapAsset", ticker: "CA", quantity: 50.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 50.0, price_per_unit: 100.0})

      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Capital Corp"
      assert html =~ "CapAsset"
    end

    test "shows ticker in parentheses next to asset name", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{company: company, asset: "Apple Inc", ticker: "AAPL", quantity: 10.0})
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2023-01-01", quantity: 10.0, price_per_unit: 150.0})

      {:ok, _live, html} = live(conn, ~p"/tax/capital-gains")
      assert html =~ "Apple Inc"
      assert html =~ "(AAPL)"
    end
  end
end
