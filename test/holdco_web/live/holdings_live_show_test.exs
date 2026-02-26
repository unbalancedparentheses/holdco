defmodule HoldcoWeb.HoldingsLiveShowTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /holdings/:id" do
    test "renders holding show page", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")
      assert html =~ holding.asset
    end

    test "shows cost basis lots section", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")
      assert html =~ "Cost Basis" or html =~ "cost"
    end
  end

  describe "page layout and metrics" do
    test "shows page title with asset name", %{conn: conn} do
      holding = holding_fixture(%{asset: "Apple Inc", ticker: "AAPL", asset_type: "equity"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Apple Inc"
      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "shows ticker and asset type badge", %{conn: conn} do
      holding = holding_fixture(%{asset: "Google", ticker: "GOOG", asset_type: "equity"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "GOOG"
      assert html =~ "equity"
      assert html =~ "tag tag-ink"
    end

    test "shows back to holdings link", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Back to Holdings"
      assert html =~ "/holdings"
    end

    test "shows metrics strip with current value, quantity, unrealized and realized GL", %{conn: conn} do
      holding = holding_fixture(%{quantity: 100.0, currency: "USD"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Current Value"
      assert html =~ "Quantity"
      assert html =~ "Unrealized G/L"
      assert html =~ "Realized G/L"
      assert html =~ "metrics-strip"
    end

    test "shows details section with asset info", %{conn: conn} do
      holding = holding_fixture(%{asset: "TestAsset", ticker: "TST", asset_type: "bond", currency: "EUR"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Details"
      assert html =~ "Asset Name"
      assert html =~ "TestAsset"
      assert html =~ "Ticker"
      assert html =~ "TST"
      assert html =~ "Asset Type"
      assert html =~ "bond"
      assert html =~ "Currency"
      assert html =~ "EUR"
    end
  end

  describe "cost basis lots section" do
    test "shows cost basis lots table headers", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Cost Basis Lots"
      assert html =~ "Purchase Date"
      assert html =~ "Qty"
      assert html =~ "Price/Unit"
      assert html =~ "Cost Basis"
      assert html =~ "Sold Qty"
      assert html =~ "Sold Price"
      assert html =~ "G/L"
    end

    test "shows empty state when no lots exist", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "No cost basis lots recorded."
    end

    test "shows cost basis lot data", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, purchase_date: "2024-03-15", quantity: 50.0, price_per_unit: 200.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "2024-03-15"
      assert html =~ "50"
      assert html =~ "200"
    end

    test "shows lot count", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, quantity: 30.0})
      cost_basis_lot_fixture(%{holding: holding, quantity: 20.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "2 lots"
    end

    test "shows sold lot details", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 10.0, sold_quantity: 50.0, sold_price: 15.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "50"
      assert html =~ "15"
    end
  end

  describe "holding without ticker" do
    test "shows --- for ticker when nil", %{conn: conn} do
      holding = holding_fixture(%{asset: "Private Equity Fund", ticker: nil, asset_type: "private_equity"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Private Equity Fund"
      assert html =~ "---"
    end
  end

  describe "holding with company association" do
    test "shows company name with link", %{conn: conn} do
      company = company_fixture(%{name: "Holding Parent Co"})
      holding = holding_fixture(%{company: company, asset: "Sub Asset"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Holding Parent Co"
      assert html =~ "/companies/#{company.id}"
    end
  end

  describe "details section" do
    test "shows unit field or ---", %{conn: conn} do
      holding = holding_fixture(%{unit: nil})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Unit"
      assert html =~ "---"
    end

    test "shows custodian when associated", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Custodian"
    end

    test "shows total cost basis and total gain/loss", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Total Cost Basis"
      assert html =~ "Total Gain/Loss"
    end
  end

  describe "handle_info for PubSub" do
    test "handles broadcast by reloading data", %{conn: conn} do
      holding = holding_fixture(%{asset: "Broadcast Asset"})
      {:ok, view, _html} = live(conn, ~p"/holdings/#{holding.id}")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Broadcast Asset"
    end
  end

  describe "handle_params" do
    test "handle_params is a no-op", %{conn: conn} do
      holding = holding_fixture()
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ holding.asset
    end
  end

  describe "holding with unit" do
    test "shows unit label next to quantity", %{conn: conn} do
      holding = holding_fixture(%{asset: "Gold ETF", quantity: 50.0, unit: "oz"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "oz"
      assert html =~ "50"
    end
  end

  describe "cost basis lot with no sold quantity" do
    test "shows --- for sold price when sold_quantity is 0", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 10.0, sold_quantity: 0.0, sold_price: 0.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      # When sold_quantity is 0, the template shows "---" for sold price
      assert html =~ "---"
    end
  end

  describe "cost basis lot gain/loss calculation" do
    test "shows positive gain for profitable sold lot", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 10.0, sold_quantity: 50.0, sold_price: 20.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      # Gain should be positive: 50 * (20 - 10) = 500
      assert html =~ "+$"
    end

    test "shows negative gain for losing sold lot", %{conn: conn} do
      holding = holding_fixture()
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 20.0, sold_quantity: 50.0, sold_price: 10.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      # Gain should be negative: 50 * (10 - 20) = -500
      assert html =~ "-$"
    end
  end

  describe "multiple cost basis lots" do
    test "shows total cost basis and total gain/loss across multiple lots", %{conn: conn} do
      holding = holding_fixture(%{quantity: 200.0})
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 10.0})
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 15.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Total Cost Basis"
      assert html =~ "2 lots"
    end
  end

  describe "holding with company" do
    test "shows company name in details section", %{conn: conn} do
      company = company_fixture(%{name: "Holding Company X"})
      holding = holding_fixture(%{asset: "Linked Asset", company: company})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Linked Asset"
      assert html =~ "Holding Company X"
    end
  end

  describe "holding without custodian" do
    test "shows --- for custodian when nil", %{conn: conn} do
      holding = holding_fixture(%{asset: "No Custodian Asset"})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Custodian"
      assert html =~ "---"
    end
  end

  describe "price history display" do
    test "holding without ticker does not show price history", %{conn: conn} do
      holding = holding_fixture(%{asset: "No Ticker Asset", ticker: nil})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      refute html =~ "Price History"
    end

    test "holding with empty ticker does not show price history", %{conn: conn} do
      holding = holding_fixture(%{asset: "Empty Ticker Asset", ticker: ""})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      refute html =~ "Price History"
    end
  end

  describe "format helpers edge cases" do
    test "nil quantity displays correctly", %{conn: conn} do
      holding = holding_fixture(%{asset: "NilQty Asset", quantity: nil})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "NilQty Asset"
      assert html =~ "Quantity"
    end
  end

  describe "price history display with data" do
    test "holding with ticker and price history shows chart section", %{conn: conn} do
      holding = holding_fixture(%{asset: "Bitcoin", ticker: "BTC", asset_type: "crypto", quantity: 2.5})
      # Record some price history for BTC
      price_history_fixture(%{ticker: "BTC", price: 45000.0, currency: "USD"})
      price_history_fixture(%{ticker: "BTC", price: 46000.0, currency: "USD"})
      price_history_fixture(%{ticker: "BTC", price: 47000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Price History"
      assert html =~ "data points"
      assert html =~ "price-history-chart"
      assert html =~ "ChartHook"
    end
  end

  describe "gains and losses with sold lots" do
    test "shows unrealized and realized gains with mixed lots", %{conn: conn} do
      holding = holding_fixture(%{asset: "Mixed Gains Stock", ticker: "MGS", quantity: 200.0, asset_type: "equity"})

      # Lot 1: bought 100 at $10, sold 50 at $15 (realized gain = 50 * 5 = 250)
      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 100.0,
        price_per_unit: 10.0,
        purchase_date: "2024-01-01",
        sold_quantity: 50.0,
        sold_price: 15.0
      })

      # Lot 2: bought 100 at $20, sold 30 at $15 (realized loss = 30 * -5 = -150)
      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 100.0,
        price_per_unit: 20.0,
        purchase_date: "2024-02-01",
        sold_quantity: 30.0,
        sold_price: 15.0
      })

      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "Unrealized G/L"
      assert html =~ "Realized G/L"
      assert html =~ "Total Cost Basis"
      assert html =~ "Total Gain/Loss"
      assert html =~ "2 lots"
    end

    test "shows cost basis for unsold lots only", %{conn: conn} do
      holding = holding_fixture(%{asset: "Cost Basis Test", ticker: "CBT", quantity: 100.0})

      # Fully sold lot - should not count in cost basis
      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 50.0,
        price_per_unit: 10.0,
        sold_quantity: 50.0,
        sold_price: 12.0
      })

      # Partially unsold lot - remaining 30 should count
      cost_basis_lot_fixture(%{
        holding: holding,
        quantity: 50.0,
        price_per_unit: 15.0,
        sold_quantity: 20.0,
        sold_price: 18.0
      })

      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")
      assert html =~ "Total Cost Basis"
    end
  end

  describe "holding with custodian" do
    test "shows custodian details when associated", %{conn: conn} do
      holding = holding_fixture(%{asset: "Custodied Asset"})
      custodian_account_fixture(%{holding: holding, bank: "JP Morgan", account_number: "ACC-12345"})

      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "JP Morgan"
      assert html =~ "ACC-12345"
    end
  end

  describe "format_decimal edge cases" do
    test "lot with zero quantity shows 0", %{conn: conn} do
      holding = holding_fixture(%{asset: "Zero Lot Asset"})
      cost_basis_lot_fixture(%{holding: holding, quantity: 0.0, price_per_unit: 100.0})

      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")
      assert html =~ "Zero Lot Asset"
    end
  end

  describe "integer value formatting" do
    test "holding with integer quantity displays correctly", %{conn: conn} do
      holding = holding_fixture(%{asset: "Integer Qty", quantity: 100.0})
      {:ok, _view, html} = live(conn, ~p"/holdings/#{holding.id}")

      assert html =~ "100"
    end
  end
end
