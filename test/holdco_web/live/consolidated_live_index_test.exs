defmodule HoldcoWeb.ConsolidatedLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Consolidated Financial Statements page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Consolidated Financial Statements"
      assert html =~ "Group-level balance sheet and income statement"
    end

    test "shows metrics strip with all labels", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Entities"
      assert html =~ "Total Assets (Consol.)"
      assert html =~ "Total Equity (Consol.)"
      assert html =~ "Intercompany Eliminations"
      assert html =~ "NCI (Non-Controlling)"
    end

    test "shows tab buttons for balance sheet, income statement, and eliminations", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Balance Sheet"
      assert html =~ "Income Statement"
      assert html =~ "Eliminations"
    end

    test "defaults to balance sheet tab", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Consolidated Balance Sheet"
      assert html =~ "Assets"
      assert html =~ "Liabilities"
      assert html =~ "Equity"
      assert html =~ "Non-Controlling Interest"
    end

    test "balance sheet shows Total Assets row", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Total Assets"
    end

    test "balance sheet shows Total Liabilities row", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Total Liabilities"
    end

    test "balance sheet shows Total Equity row", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Total Equity"
    end
  end

  describe "switch_tab" do
    test "switches to income statement tab", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Consolidated Income Statement"
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net Income (Consolidated)"
      assert html =~ "Attributable to Parent"
      assert html =~ "Attributable to NCI"
    end

    test "switches to eliminations tab", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "Intercompany Eliminations"
      assert html =~ "Non-Controlling Interest by Entity"
    end

    test "switches back to balance sheet tab", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      render_click(live, "switch_tab", %{"tab" => "income_statement"})
      html = render_click(live, "switch_tab", %{"tab" => "balance_sheet"})
      assert html =~ "Consolidated Balance Sheet"
      assert html =~ "Assets"
    end

    test "eliminations tab shows transfer table columns", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "Date"
      assert html =~ "From Entity"
      assert html =~ "To Entity"
      assert html =~ "Description"
      assert html =~ "Amount"
      assert html =~ "Currency"
      assert html =~ "Total Eliminations"
    end

    test "eliminations tab shows empty state when no transfers", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "No intercompany transfers recorded"
    end

    test "NCI by entity table shows ownership columns", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "Ownership %"
      assert html =~ "NCI %"
      assert html =~ "Entity Equity"
      assert html =~ "NCI Value"
      assert html =~ "Total NCI"
    end
  end

  describe "with multi-company data" do
    test "renders multiple company columns in balance sheet", %{conn: conn} do
      c1 = company_fixture(%{name: "Parent LLC"})
      c2 = company_fixture(%{name: "Sub LLC"})
      account_fixture(%{company: c1, account_type: "asset", code: "1100", name: "Cash"})
      account_fixture(%{company: c2, account_type: "asset", code: "1101", name: "Cash Sub"})

      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Parent LLC"
      assert html =~ "Sub LLC"
      assert html =~ "Elim."
      assert html =~ "NCI"
      assert html =~ "Consolidated"
    end

    test "renders company columns in income statement", %{conn: conn} do
      c1 = company_fixture(%{name: "ISParent"})
      c2 = company_fixture(%{name: "ISSub"})
      account_fixture(%{company: c1, account_type: "revenue", code: "4100", name: "Revenue Parent"})
      account_fixture(%{company: c2, account_type: "expense", code: "5100", name: "Expense Sub"})

      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
    end

    test "short_name truncates long company names", %{conn: conn} do
      company_fixture(%{name: "A Very Long Company Name That Exceeds Twelve Characters"})

      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "A Very Long .."
    end
  end

  describe "with intercompany transfers" do
    test "shows transfer data in eliminations tab", %{conn: conn} do
      c1 = company_fixture(%{name: "TransferFrom"})
      c2 = company_fixture(%{name: "TransferTo"})
      inter_company_transfer_fixture(%{
        from_company: c1,
        to_company: c2,
        amount: 25_000.0,
        date: "2024-06-01",
        description: "Management Fee"
      })

      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "TransferFrom"
      assert html =~ "TransferTo"
      assert html =~ "Management Fee"
      assert html =~ "25,000"
    end

    test "shows total eliminations sum", %{conn: conn} do
      c1 = company_fixture(%{name: "ElimFrom"})
      c2 = company_fixture(%{name: "ElimTo"})
      inter_company_transfer_fixture(%{from_company: c1, to_company: c2, amount: 10_000.0, date: "2024-01-01"})
      inter_company_transfer_fixture(%{from_company: c1, to_company: c2, amount: 15_000.0, date: "2024-02-01"})

      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "Total Eliminations"
      assert html =~ "25,000"
    end
  end

  describe "with partial ownership (NCI)" do
    test "shows NCI percentage for partially owned company", %{conn: conn} do
      company_fixture(%{name: "FullOwned", ownership_pct: 100})
      company_fixture(%{name: "PartialOwned", ownership_pct: 70})

      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "70%"
      assert html =~ "30%"
      assert html =~ "0%"
    end

    test "income statement shows NCI share breakdown", %{conn: conn} do
      company_fixture(%{name: "NCI IS Co", ownership_pct: 80})

      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Attributable to Parent"
      assert html =~ "Attributable to NCI"
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "noop", %{})
      assert html =~ "Consolidated Financial Statements"
    end
  end
end
