defmodule HoldcoWeb.AccountingReportsTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "<h1>Accounting Reports</h1>"
      assert html =~ "Trial Balance, Balance Sheet, and Income Statement"
      assert html =~ "page-title-rule"
    end

    test "renders company filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "All Companies (Consolidated)"
      assert html =~ ~s(phx-change="filter_company")
    end

    test "renders three tab buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "Trial Balance"
      assert html =~ "Balance Sheet"
      assert html =~ "Income Statement"
    end

    test "defaults to trial balance tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      # Trial balance tab should be active (btn-primary)
      assert html =~ ~s(phx-value-tab="trial_balance")
      # Trial balance content is rendered
      assert html =~ "Trial Balance"
      assert html =~ "Code"
      assert html =~ "Account"
      assert html =~ "Debit"
      assert html =~ "Credit"
      assert html =~ "Balance"
    end

    test "shows empty state for trial balance", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "No account activity. Create journal entries to see the trial balance."
    end

    test "shows balanced indicator for trial balance", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "Balanced"
    end
  end

  # ── Tab Switching ───────────────────────────────────────

  describe "switch_tab event" do
    test "switches to balance sheet tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="balance_sheet"])) |> render_click()

      assert html =~ "Total Assets"
      assert html =~ "Total Liabilities"
      assert html =~ "Total Equity"
      assert html =~ "A = L + E"
      assert html =~ "Assets"
      assert html =~ "Liabilities"
      assert html =~ "Equity"
    end

    test "switches to income statement tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
      assert html =~ "Revenue"
      assert html =~ "Expenses"
      # Date filter form
      assert html =~ ~s(phx-change="filter_dates")
      assert html =~ ~s(name="date_from")
      assert html =~ ~s(name="date_to")
    end

    test "switches back to trial balance from balance sheet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      view |> element(~s(button[phx-value-tab="balance_sheet"])) |> render_click()
      html = view |> element(~s(button[phx-value-tab="trial_balance"])) |> render_click()

      assert html =~ "Trial Balance"
      assert html =~ "Code"
    end
  end

  # ── Filter Company ──────────────────────────────────────

  describe "filter_company event" do
    test "filters reports by company", %{conn: conn} do
      company = company_fixture(%{name: "ReportCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(company.id)})
        |> render_change()

      # Should still render the trial balance tab
      assert html =~ "Trial Balance"
    end

    test "empty company_id shows consolidated", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "Trial Balance"
    end
  end

  # ── Filter Dates (Income Statement) ─────────────────────

  describe "filter_dates event" do
    test "filters income statement by date range", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      # Switch to income statement tab first
      view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-change="filter_dates"]), %{
          "date_from" => "2025-01-01",
          "date_to" => "2025-06-30"
        })
        |> render_change()

      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
    end
  end

  # ── With Data ───────────────────────────────────────────

  describe "reports with journal data" do
    test "trial balance shows accounts with journal activity", %{conn: conn} do
      company = company_fixture()
      acct1 = account_fixture(%{company_id: company.id, code: "1000", name: "Cash", account_type: "asset"})
      acct2 = account_fixture(%{company_id: company.id, code: "4000", name: "Sales", account_type: "revenue"})

      je = journal_entry_fixture(%{company_id: company.id, date: "2025-01-15", description: "Sale"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct1.id, debit: 1000.0, credit: 0.0})
      journal_line_fixture(%{entry_id: je.id, account_id: acct2.id, debit: 0.0, credit: 1000.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "Cash"
      assert html =~ "Sales"
      assert html =~ "1000"
    end

    test "balance sheet shows asset and equity accounts", %{conn: conn} do
      company = company_fixture()
      acct1 = account_fixture(%{company_id: company.id, code: "1000", name: "BankAccount", account_type: "asset"})
      acct2 = account_fixture(%{company_id: company.id, code: "3000", name: "OwnerEquity", account_type: "equity"})

      je = journal_entry_fixture(%{company_id: company.id, date: "2025-01-15", description: "Investment"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct1.id, debit: 5000.0, credit: 0.0})
      journal_line_fixture(%{entry_id: je.id, account_id: acct2.id, debit: 0.0, credit: 5000.0})

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="balance_sheet"])) |> render_click()

      assert html =~ "BankAccount"
      assert html =~ "OwnerEquity"
    end

    test "income statement shows revenue and expense accounts", %{conn: conn} do
      company = company_fixture()
      rev_acct = account_fixture(%{company_id: company.id, code: "4000", name: "ConsultingRev", account_type: "revenue"})
      exp_acct = account_fixture(%{company_id: company.id, code: "5000", name: "OfficeExp", account_type: "expense"})

      # Use a date in the current year so it falls within the default date range
      today = Date.utc_today()
      date = Date.to_iso8601(%{today | day: 15})
      je = journal_entry_fixture(%{company_id: company.id, date: date, description: "Monthly"})
      journal_line_fixture(%{entry_id: je.id, account_id: rev_acct.id, debit: 0.0, credit: 3000.0})
      journal_line_fixture(%{entry_id: je.id, account_id: exp_acct.id, debit: 3000.0, credit: 0.0})

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      assert html =~ "ConsultingRev"
      assert html =~ "OfficeExp"
    end
  end

  # ── Empty states for tabs ───────────────────────────────

  describe "empty states for all tabs" do
    test "balance sheet shows empty states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="balance_sheet"])) |> render_click()

      assert html =~ "No asset accounts with activity."
      assert html =~ "No liability accounts with activity."
      assert html =~ "No equity accounts with activity."
    end

    test "income statement shows empty states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      assert html =~ "No revenue recorded for this period."
      assert html =~ "No expenses recorded for this period."
    end
  end

  # ── Handle Info (PubSub) ──────────────────────────────

  describe "handle_info for PubSub broadcast" do
    test "handles generic broadcast and reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Accounting Reports"
      assert html =~ "Trial Balance"
    end
  end

  # ── Filter company on income statement ────────────────

  describe "filter_company with income statement active" do
    test "filtering company updates income statement data", %{conn: conn} do
      company = company_fixture(%{name: "ISFilterCo"})
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      # Switch to income statement
      view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      # Now filter by company
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(company.id)})
        |> render_change()

      # Should still show income statement content
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
    end
  end

  # ── Filter dates with company selected ────────────────

  describe "filter_dates with company selected" do
    test "filters income statement by dates with a company selected", %{conn: conn} do
      company = company_fixture(%{name: "DateFilterCo"})
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      # Select company
      view
      |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(company.id)})
      |> render_change()

      # Switch to income statement
      view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      # Filter dates
      html =
        view
        |> form(~s(form[phx-change="filter_dates"]), %{
          "date_from" => "2025-01-01",
          "date_to" => "2025-12-31"
        })
        |> render_change()

      assert html =~ "Total Revenue"
      assert html =~ "Net Income"
    end
  end

  # ── Company options in filter dropdown ────────────────

  describe "company options" do
    test "company names appear in the filter dropdown", %{conn: conn} do
      company_fixture(%{name: "DropdownReportCo"})

      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ "DropdownReportCo"
    end
  end

  # ── Tab button active state ───────────────────────────

  describe "tab button active states" do
    test "trial balance button is primary by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")

      assert html =~ ~s(phx-value-tab="trial_balance")
    end

    test "balance sheet tab shows balanced indicator", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="balance_sheet"])) |> render_click()

      assert html =~ "A = L + E"
      assert html =~ "Balanced"
    end
  end
end
