defmodule HoldcoWeb.AccountingReportsTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user


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

      # Use a date in the current year that's always in the past (Jan 10)
      today = Date.utc_today()
      date = Date.to_iso8601(%{today | month: 1, day: 10})
      je = journal_entry_fixture(%{company_id: company.id, date: date, description: "Monthly"})
      journal_line_fixture(%{entry_id: je.id, account_id: rev_acct.id, debit: 0.0, credit: 3000.0})
      journal_line_fixture(%{entry_id: je.id, account_id: exp_acct.id, debit: 3000.0, credit: 0.0})

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")

      html = view |> element(~s(button[phx-value-tab="income_statement"])) |> render_click()

      assert html =~ "ConsultingRev"
      assert html =~ "OfficeExp"
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

end
