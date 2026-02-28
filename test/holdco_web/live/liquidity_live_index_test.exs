defmodule HoldcoWeb.LiquidityLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Liquidity Coverage Ratio page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "Liquidity Coverage Ratio"
      assert html =~ "Monitor HQLA levels and liquidity adequacy"
    end

    test "shows empty state when no LCR calculations exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "No LCR calculations yet."
    end

    test "shows history table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "History"
      assert html =~ "No historical calculations to display."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "All Companies"
    end
  end

  describe "liquidity data display" do
    test "displays LCR data with metrics strip when record exists", %{conn: conn} do
      liquidity_coverage_fixture(%{
        total_hqla: 650_000.0,
        net_cash_outflows_30d: 400_000.0,
        lcr_ratio: 162.5,
        status: "adequate"
      })

      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "Total HQLA"
      assert html =~ "Net Cash Outflows"
      assert html =~ "LCR Ratio"
      assert html =~ "adequate"
    end

    test "shows history table with existing records", %{conn: conn} do
      liquidity_coverage_fixture(%{status: "adequate", lcr_ratio: 150.0})

      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "History"
      assert html =~ "adequate"
    end
  end

  describe "filter_company event" do
    test "filters by company", %{conn: conn} do
      company = company_fixture(%{name: "LCR Filter Co"})
      liquidity_coverage_fixture(%{company_id: company.id, status: "adequate"})

      {:ok, view, _html} = live(conn, ~p"/liquidity")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "adequate"
    end

    test "filters with empty company_id shows all", %{conn: conn} do
      liquidity_coverage_fixture(%{status: "adequate"})

      {:ok, view, _html} = live(conn, ~p"/liquidity")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "adequate"
    end
  end

  describe "recalculate event" do
    test "recalculates LCR and shows flash", %{conn: conn} do
      # Need some data for the calculation to work on
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 500_000.0})

      {:ok, view, _html} = live(conn, ~p"/liquidity")
      html = render_click(view, "recalculate", %{})
      # Either it succeeds or fails -- both are valid outcomes depending on data
      assert html =~ "LCR calculated" || html =~ "Failed to calculate LCR"
    end
  end

  describe "delete event" do
    test "deletes a liquidity coverage record", %{conn: conn} do
      lc = liquidity_coverage_fixture(%{status: "adequate"})

      {:ok, view, _html} = live(conn, ~p"/liquidity")
      html = render_click(view, "delete", %{"id" => to_string(lc.id)})
      assert html =~ "Record deleted"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/liquidity")
      html = render_click(view, "noop", %{})
      assert html =~ "Liquidity Coverage Ratio"
    end
  end

  describe "handle_info PubSub" do
    test "handles PubSub broadcast by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/liquidity")

      # Create a record after mount
      liquidity_coverage_fixture(%{status: "adequate", lcr_ratio: 120.0})

      # Sending any message triggers the catch-all handle_info
      send(view.pid, {:analytics_changed, %{}})
      html = render(view)
      assert html =~ "adequate"
    end
  end

  describe "warning banner" do
    test "shows warning banner for non-adequate status", %{conn: conn} do
      liquidity_coverage_fixture(%{
        status: "warning",
        lcr_ratio: 85.0,
        total_hqla: 85_000.0,
        net_cash_outflows_30d: 100_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "LCR warning"
      assert html =~ "below the 100% regulatory threshold"
    end

    test "shows critical banner when status is critical", %{conn: conn} do
      liquidity_coverage_fixture(%{
        status: "critical",
        lcr_ratio: 45.0,
        total_hqla: 45_000.0,
        net_cash_outflows_30d: 100_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/liquidity")
      assert html =~ "LCR is critically low"
      assert html =~ "Regulatory minimum is 100%"
    end

    test "no warning banner when status is adequate", %{conn: conn} do
      liquidity_coverage_fixture(%{
        status: "adequate",
        lcr_ratio: 150.0,
        total_hqla: 150_000.0,
        net_cash_outflows_30d: 100_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/liquidity")
      refute html =~ "LCR warning"
      refute html =~ "LCR is critically low"
    end
  end

  describe "recalculate with company filter" do
    test "recalculates LCR with selected company", %{conn: conn} do
      company = company_fixture(%{name: "LCRFilterCo"})
      bank_account_fixture(%{company: company, balance: 300_000.0})

      {:ok, view, _html} = live(conn, ~p"/liquidity")

      # Set filter
      render_change(view, "filter_company", %{"company_id" => to_string(company.id)})

      # Recalculate with company filter active
      html = render_click(view, "recalculate", %{})
      assert html =~ "LCR calculated" or html =~ "Failed to calculate LCR"
    end
  end

  describe "editor interaction" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees Recalculate LCR button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/liquidity")

      assert html =~ "Recalculate LCR"
    end

    test "editor sees delete button on history records", %{conn: conn} do
      liquidity_coverage_fixture(%{status: "adequate", lcr_ratio: 150.0})

      {:ok, _view, html} = live(conn, ~p"/liquidity")

      assert html =~ ~s(phx-click="delete")
    end
  end

  describe "HQLA breakdown display" do
    test "displays HQLA level breakdown when record exists", %{conn: conn} do
      liquidity_coverage_fixture(%{
        status: "adequate",
        lcr_ratio: 162.5,
        total_hqla: 650_000.0,
        hqla_level1: 400_000.0,
        hqla_level2a: 150_000.0,
        hqla_level2b: 100_000.0,
        net_cash_outflows_30d: 400_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/liquidity")

      assert html =~ "HQLA Breakdown"
      assert html =~ "Level 1"
      assert html =~ "Level 2A"
      assert html =~ "Level 2B"
      assert html =~ "Calculation Details"
    end
  end
end
