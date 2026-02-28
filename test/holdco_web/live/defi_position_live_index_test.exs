defmodule HoldcoWeb.DefiPositionLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders DeFi Positions page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "DeFi Positions"
      assert html =~ "Track DeFi protocol positions across chains"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "Total Positions"
      assert html =~ "Active"
      assert html =~ "Total Value"
    end

    test "shows positions table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "Protocol"
      assert html =~ "Chain"
      assert html =~ "Deposited"
      assert html =~ "Current Value"
      assert html =~ "APY"
    end

    test "shows empty state when no positions", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "No DeFi positions found"
    end

    test "shows action buttons", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "Refresh Prices"
      assert html =~ "Add Position"
    end

    test "shows chain and protocol filters", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/defi-positions")
      assert html =~ "All Chains"
      assert html =~ "All Protocols"
    end

    test "opens add position form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/defi-positions")
      html = render_click(live, "show_form")
      assert html =~ "Add DeFi Position"
      assert html =~ "Protocol Name"
      assert html =~ "Wallet Address"
    end
  end

  describe "close_form" do
    test "closes the add position form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "save (create defi position)" do
    test "creates a defi position with valid data", %{conn: conn} do
      company = company_fixture(%{name: "DeFi Corp"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "defi_position" => %{
            "company_id" => to_string(company.id),
            "protocol_name" => "Uniswap",
            "chain" => "ethereum",
            "position_type" => "liquidity_pool",
            "asset_pair" => "ETH/USDC",
            "deposited_amount" => "5000",
            "current_value" => "5200",
            "apy_current" => "12.5",
            "currency" => "USD",
            "status" => "active",
            "entry_date" => "2025-01-15"
          }
        })

      assert html =~ "DeFi position created"
      assert html =~ "Uniswap"
    end

    test "shows error when creating with missing fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "defi_position" => %{
            "protocol_name" => "",
            "chain" => ""
          }
        })

      assert html =~ "Failed to create DeFi position"
    end
  end

  describe "edit" do
    test "opens edit form for an existing position", %{conn: conn} do
      company = company_fixture()
      position = defi_position_fixture(%{company: company, protocol_name: "Aave"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "edit", %{"id" => to_string(position.id)})

      assert html =~ "Edit DeFi Position"
      assert html =~ "Update Position"
    end
  end

  describe "update" do
    test "updates a defi position", %{conn: conn} do
      company = company_fixture()
      position = defi_position_fixture(%{company: company, protocol_name: "OldProtocol"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      render_click(view, "edit", %{"id" => to_string(position.id)})

      html =
        render_click(view, "update", %{
          "defi_position" => %{
            "company_id" => to_string(company.id),
            "protocol_name" => "UpdatedProtocol",
            "chain" => "ethereum",
            "position_type" => "lending",
            "current_value" => "15000"
          }
        })

      assert html =~ "DeFi position updated"
      assert html =~ "UpdatedProtocol"
    end
  end

  describe "delete" do
    test "deletes a defi position", %{conn: conn} do
      company = company_fixture()
      position = defi_position_fixture(%{company: company, protocol_name: "DeleteMeProtocol"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      assert render(view) =~ "DeleteMeProtocol"

      html = render_click(view, "delete", %{"id" => to_string(position.id)})
      assert html =~ "DeFi position deleted"
      refute html =~ "DeleteMeProtocol"
    end
  end

  describe "filter_chain" do
    test "filters positions by chain", %{conn: conn} do
      company = company_fixture()
      defi_position_fixture(%{company: company, chain: "ethereum", protocol_name: "EthProtocol"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "filter_chain", %{"chain" => "ethereum"})
      assert html =~ "EthProtocol"
    end

    test "clears chain filter with empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "filter_chain", %{"chain" => ""})
      assert html =~ "All DeFi Positions"
    end
  end

  describe "filter_protocol" do
    test "filters positions by protocol", %{conn: conn} do
      company = company_fixture()
      defi_position_fixture(%{company: company, protocol_name: "Compound"})

      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "filter_protocol", %{"protocol" => "Compound"})
      assert html =~ "Compound"
    end

    test "clears protocol filter with empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "filter_protocol", %{"protocol" => ""})
      assert html =~ "All DeFi Positions"
    end
  end

  describe "refresh_prices" do
    test "queues a price refresh job", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/defi-positions")
      html = render_click(view, "refresh_prices")
      assert html =~ "Price refresh queued"
    end
  end

  describe "displays existing data" do
    test "shows position in table", %{conn: conn} do
      company = company_fixture(%{name: "DeFi Display Corp"})
      defi_position_fixture(%{company: company, protocol_name: "VisibleProtocol", chain: "ethereum", asset_pair: "WBTC/ETH"})

      {:ok, _view, html} = live(conn, ~p"/defi-positions")
      assert html =~ "VisibleProtocol"
      assert html =~ "WBTC/ETH"
    end
  end
end
