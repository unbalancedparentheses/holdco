defmodule HoldcoWeb.EntityComparisonLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "toggle_company" do
    test "toggles a single company selection", %{conn: conn} do
      company = company_fixture(%{name: "Toggle Corp"})
      {:ok, live, _html} = live(conn, ~p"/compare")
      html = render_click(live, "toggle_company", %{"id" => to_string(company.id)})
      assert html =~ "Selected:"
      assert html =~ "Toggle Corp"
      # Still shows empty state because only 1 selected
      assert html =~ "Select at least 2 entities"
    end

    test "selecting two companies shows comparison tables", %{conn: conn} do
      c1 = company_fixture(%{name: "Entity A"})
      c2 = company_fixture(%{name: "Entity B"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      html = render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      assert html =~ "Balance Sheet"
      assert html =~ "Income Statement"
      assert html =~ "Assets"
      assert html =~ "Total Assets"
    end

    test "deselecting a company toggles it off", %{conn: conn} do
      c1 = company_fixture(%{name: "Deselect A"})
      c2 = company_fixture(%{name: "Deselect B"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})
      # Deselect first one
      html = render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      # Should go back to empty state (only 1 selected)
      assert html =~ "Select at least 2 entities"
    end

    test "limits selection to 4 entities", %{conn: conn} do
      c1 = company_fixture(%{name: "MaxA"})
      c2 = company_fixture(%{name: "MaxB"})
      c3 = company_fixture(%{name: "MaxC"})
      c4 = company_fixture(%{name: "MaxD"})
      c5 = company_fixture(%{name: "MaxE"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c3.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c4.id)})
      html = render_click(live, "toggle_company", %{"id" => to_string(c5.id)})

      assert html =~ "Maximum 4 entities selected"
      # MaxE should not appear in selected list
      assert html =~ "MaxA"
      assert html =~ "MaxB"
      assert html =~ "MaxC"
      assert html =~ "MaxD"
    end
  end

  describe "remove_company" do
    test "removes a company from the selection", %{conn: conn} do
      c1 = company_fixture(%{name: "Remove A"})
      c2 = company_fixture(%{name: "Remove B"})
      c3 = company_fixture(%{name: "Remove C"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c3.id)})

      html = render_click(live, "remove_company", %{"id" => to_string(c2.id)})
      assert html =~ "Remove A"
      assert html =~ "Remove C"
    end
  end

  describe "switch_tab" do
    test "switches to income statement tab", %{conn: conn} do
      c1 = company_fixture(%{name: "Tab A"})
      c2 = company_fixture(%{name: "Tab B"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net Income"
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
    end

    test "switches back to balance sheet tab", %{conn: conn} do
      c1 = company_fixture(%{name: "TabBack A"})
      c2 = company_fixture(%{name: "TabBack B"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      render_click(live, "switch_tab", %{"tab" => "income_statement"})
      html = render_click(live, "switch_tab", %{"tab" => "balance_sheet"})
      assert html =~ "Assets"
      assert html =~ "Liabilities"
      assert html =~ "Equity"
      assert html =~ "Total Assets"
    end
  end

  describe "balance sheet comparison with accounts" do
    test "shows account rows in balance sheet", %{conn: conn} do
      c1 = company_fixture(%{name: "AcctCo A"})
      c2 = company_fixture(%{name: "AcctCo B"})
      account_fixture(%{company: c1, account_type: "asset", code: "1000", name: "Cash"})
      account_fixture(%{company: c2, account_type: "asset", code: "1001", name: "Cash B"})
      account_fixture(%{company: c1, account_type: "liability", code: "2000", name: "Accounts Payable"})
      account_fixture(%{company: c1, account_type: "equity", code: "3000", name: "Retained Earnings"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      html = render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      assert html =~ "AcctCo A"
      assert html =~ "AcctCo B"
      assert html =~ "Assets"
      assert html =~ "Liabilities"
      assert html =~ "Equity"
    end
  end

  describe "income statement comparison with accounts" do
    test "shows revenue and expense rows in income statement", %{conn: conn} do
      c1 = company_fixture(%{name: "ISCo A"})
      c2 = company_fixture(%{name: "ISCo B"})
      account_fixture(%{company: c1, account_type: "revenue", code: "4000", name: "Sales"})
      account_fixture(%{company: c2, account_type: "revenue", code: "4001", name: "Sales B"})
      account_fixture(%{company: c1, account_type: "expense", code: "5000", name: "COGS"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net Income"
    end
  end

  describe "balance sheet with journal entries" do
    test "shows account balances side by side", %{conn: conn} do
      c1 = company_fixture(%{name: "BSJournalA"})
      c2 = company_fixture(%{name: "BSJournalB"})

      a1 = account_fixture(%{company: c1, account_type: "asset", code: "1100", name: "Cash A"})
      a2 = account_fixture(%{company: c1, account_type: "equity", code: "3100", name: "Equity A"})
      a3 = account_fixture(%{company: c2, account_type: "asset", code: "1200", name: "Cash B"})
      a4 = account_fixture(%{company: c2, account_type: "liability", code: "2200", name: "Loan B"})

      e1 = journal_entry_fixture(%{company: c1})
      journal_line_fixture(%{entry: e1, account: a1, debit: 5000.0, credit: 0.0})
      journal_line_fixture(%{entry: e1, account: a2, debit: 0.0, credit: 5000.0})

      e2 = journal_entry_fixture(%{company: c2})
      journal_line_fixture(%{entry: e2, account: a3, debit: 3000.0, credit: 0.0})
      journal_line_fixture(%{entry: e2, account: a4, debit: 0.0, credit: 3000.0})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      html = render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      assert html =~ "BSJournalA"
      assert html =~ "BSJournalB"
      assert html =~ "Assets"
      assert html =~ "Total Assets"
      assert html =~ "5,000"
    end
  end

  describe "income statement with journal entries" do
    test "shows revenue and expense comparison", %{conn: conn} do
      c1 = company_fixture(%{name: "ISJournalA"})
      c2 = company_fixture(%{name: "ISJournalB"})

      rev1 = account_fixture(%{company: c1, account_type: "revenue", code: "4100", name: "Sales A"})
      exp1 = account_fixture(%{company: c1, account_type: "expense", code: "5100", name: "COGS A"})
      rev2 = account_fixture(%{company: c2, account_type: "revenue", code: "4200", name: "Sales B"})

      e1 = journal_entry_fixture(%{company: c1})
      journal_line_fixture(%{entry: e1, account: rev1, debit: 0.0, credit: 2000.0})
      journal_line_fixture(%{entry: e1, account: exp1, debit: 2000.0, credit: 0.0})

      e2 = journal_entry_fixture(%{company: c2})
      journal_line_fixture(%{entry: e2, account: rev2, debit: 0.0, credit: 1500.0})
      journal_line_fixture(%{entry: e2, account: account_fixture(%{company: c2, account_type: "expense", code: "5200", name: "COGS B"}), debit: 1500.0, credit: 0.0})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})

      html = render_click(live, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      assert html =~ "Net Income"
      assert html =~ "ISJournalA"
      assert html =~ "ISJournalB"
    end
  end

  describe "three companies comparison" do
    test "three companies can be selected and compared", %{conn: conn} do
      c1 = company_fixture(%{name: "TriA"})
      c2 = company_fixture(%{name: "TriB"})
      c3 = company_fixture(%{name: "TriC"})

      {:ok, live, _html} = live(conn, ~p"/compare")
      render_click(live, "toggle_company", %{"id" => to_string(c1.id)})
      render_click(live, "toggle_company", %{"id" => to_string(c2.id)})
      html = render_click(live, "toggle_company", %{"id" => to_string(c3.id)})

      assert html =~ "TriA"
      assert html =~ "TriB"
      assert html =~ "TriC"
      assert html =~ "Balance Sheet"
    end
  end
end
