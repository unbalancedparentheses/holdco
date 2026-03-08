defmodule HoldcoWeb.ConsolidatedLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

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

    test "eliminations tab shows empty state when no transfers", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "No intercompany transfers recorded"
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

  describe "with account data across entities" do
    setup do
      c1 = company_fixture(%{name: "Consol Parent", ownership_pct: 100})
      c2 = company_fixture(%{name: "Consol Sub", ownership_pct: 60})

      # Create accounts for c1
      a1_asset = account_fixture(%{company: c1, account_type: "asset", code: "1200", name: "Receivables"})
      a1_liability = account_fixture(%{company: c1, account_type: "liability", code: "2100", name: "Payables"})
      a1_equity = account_fixture(%{company: c1, account_type: "equity", code: "3100", name: "Retained Earnings"})
      a1_revenue = account_fixture(%{company: c1, account_type: "revenue", code: "4100", name: "Sales"})
      a1_expense = account_fixture(%{company: c1, account_type: "expense", code: "5100", name: "COGS"})

      # Create accounts for c2 (different codes to avoid unique constraint)
      a2_asset = account_fixture(%{company: c2, account_type: "asset", code: "1201", name: "Receivables Sub"})
      a2_revenue = account_fixture(%{company: c2, account_type: "revenue", code: "4101", name: "Sales Sub"})

      # Create journal entries with lines
      e1 = journal_entry_fixture(%{company: c1})
      journal_line_fixture(%{entry: e1, account: a1_asset, debit: 50_000.0, credit: 0.0})
      journal_line_fixture(%{entry: e1, account: a1_liability, debit: 0.0, credit: 20_000.0})
      journal_line_fixture(%{entry: e1, account: a1_equity, debit: 0.0, credit: 30_000.0})
      journal_line_fixture(%{entry: e1, account: a1_revenue, debit: 0.0, credit: 10_000.0})
      journal_line_fixture(%{entry: e1, account: a1_expense, debit: 7_000.0, credit: 0.0})

      e2 = journal_entry_fixture(%{company: c2})
      journal_line_fixture(%{entry: e2, account: a2_asset, debit: 25_000.0, credit: 0.0})
      journal_line_fixture(%{entry: e2, account: a2_revenue, debit: 0.0, credit: 5_000.0})

      %{c1: c1, c2: c2}
    end

    test "balance sheet shows account rows with entity data", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Consolidated Balance Sheet"
      # Should show the short names of companies
      assert html =~ "Consol Paren"
    end

    test "income statement shows revenue and expenses for multiple entities", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income (Consolidated)"
    end

    test "eliminations tab shows NCI percentages for partially owned entity", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "60%"
      assert html =~ "40%"
    end
  end

  describe "export button" do
    test "renders Export CSV link", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/consolidated")
      assert html =~ "Export CSV"
      assert html =~ "/export/consolidated.csv"
    end
  end

  describe "with intercompany transfers and account data" do
    setup do
      c1 = company_fixture(%{name: "ICT Parent", ownership_pct: 100})
      c2 = company_fixture(%{name: "ICT Sub", ownership_pct: 75})

      inter_company_transfer_fixture(%{
        from_company: c1,
        to_company: c2,
        amount: 50_000.0,
        date: "2024-03-15",
        description: "Capital injection",
        currency: "USD"
      })

      %{c1: c1, c2: c2}
    end

    test "eliminations tab shows transfer details with companies and descriptions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "eliminations"})
      assert html =~ "ICT Parent"
      assert html =~ "ICT Sub"
      assert html =~ "Capital injection"
      assert html =~ "50,000"
    end

    test "income statement shows NCI share for partially owned entities", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/consolidated")
      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Attributable to NCI"
    end
  end
end
