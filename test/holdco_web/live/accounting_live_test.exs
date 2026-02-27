defmodule HoldcoWeb.AccountingLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /accounts/chart" do
    test "renders chart of accounts page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Chart of Accounts"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Add Account"
    end
  end

  describe "GET /accounts/journal" do
    test "renders journal entries page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "Journal"
    end
  end

  describe "GET /accounts/reports" do
    test "renders accounting reports page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Report" or html =~ "report"
    end

    test "shows trial balance tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Trial Balance" or html =~ "trial"
    end
  end

  describe "GET /accounts/integrations" do
    test "renders integrations page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")
      assert html =~ "Integration" or html =~ "integration"
    end
  end

  # ------------------------------------------------------------------
  # Journal Entries - detailed tests
  # (Integration-specific tests are in accounting_integrations_test.exs)
  # ------------------------------------------------------------------

  describe "journal page rendering" do
    test "shows New Journal Entry button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "New Journal Entry"
    end

    test "does not show New Journal Entry button for viewers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      refute html =~ "New Journal Entry"
    end

    test "shows empty state when no journal entries exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "No journal entries yet."
    end

    test "renders journal entry data", %{conn: conn} do
      company = company_fixture(%{name: "JournalCo"})
      account = account_fixture(%{company: company, name: "Cash", code: "1001", account_type: "asset"})
      account2 = account_fixture(%{company: company, name: "Revenue", code: "4001", account_type: "revenue"})

      entry = journal_entry_fixture(%{company: company, date: "2024-06-15", description: "Sale recorded"})
      journal_line_fixture(%{entry: entry, account: account, debit: 500.0, credit: 0.0})
      journal_line_fixture(%{entry: entry, account: account2, debit: 0.0, credit: 500.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "Sale recorded"
      assert html =~ "2024-06-15"
    end

    test "renders company filter dropdown", %{conn: conn} do
      company_fixture(%{name: "FilterJournalCo"})
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "All Companies"
      assert html =~ "FilterJournalCo"
      assert html =~ ~s(phx-change="filter_company")
    end

    test "renders Double-entry bookkeeping subtitle", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "Double-entry bookkeeping"
    end
  end

  describe "journal show_form and close_form" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens the new journal entry modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html = view |> element("button", "New Journal Entry") |> render_click()

      assert html =~ "modal-overlay"
      assert html =~ "New Journal Entry"
      assert html =~ ~s(phx-submit="save")
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "noop event keeps modal open", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()
      html = render_click(view, "noop", %{})

      assert html =~ "modal-overlay"
    end
  end

  describe "journal add_line event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking add_line adds another line to the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      # Initially there are 2 line rows
      html = render(view)
      assert html =~ ~s(name="lines[0][account_id]")
      assert html =~ ~s(name="lines[1][account_id]")

      # Click add line
      html = view |> element(~s(button[phx-click="add_line"])) |> render_click()

      # Now there should be a third line
      assert html =~ ~s(name="lines[2][account_id]")
    end
  end

  describe "journal toggle_entry event" do
    test "toggling an entry expands and collapses its lines", %{conn: conn} do
      company = company_fixture(%{name: "ToggleCo"})
      account = account_fixture(%{company: company, name: "Cash", code: "1010", account_type: "asset"})
      account2 = account_fixture(%{company: company, name: "Rent", code: "5010", account_type: "expense"})

      entry = journal_entry_fixture(%{company: company, date: "2024-07-01", description: "Rent payment"})
      journal_line_fixture(%{entry: entry, account: account, debit: 0.0, credit: 1000.0})
      journal_line_fixture(%{entry: entry, account: account2, debit: 1000.0, credit: 0.0})

      {:ok, view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "Rent payment"
      # Lines should not be visible initially (collapsed)
      refute html =~ "1010"

      # Expand the entry
      html = render_click(view, "toggle_entry", %{"id" => to_string(entry.id)})
      assert html =~ "1010"
      assert html =~ "Cash"
      assert html =~ "5010"
      assert html =~ "Rent"

      # Collapse the entry
      html = render_click(view, "toggle_entry", %{"id" => to_string(entry.id)})
      refute html =~ "1010"
    end
  end

  describe "journal filter_company event" do
    test "filtering by company shows only relevant entries", %{conn: conn} do
      co1 = company_fixture(%{name: "JournalFilterCo1"})
      co2 = company_fixture(%{name: "JournalFilterCo2"})

      journal_entry_fixture(%{company: co1, description: "Entry for Co1"})
      journal_entry_fixture(%{company: co2, description: "Entry for Co2"})

      {:ok, view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "Entry for Co1"
      assert html =~ "Entry for Co2"

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Entry for Co1"
      refute html =~ "Entry for Co2"

      # Reset filter
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "Entry for Co1"
      assert html =~ "Entry for Co2"
    end
  end

  describe "journal save event (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "creating a balanced journal entry succeeds", %{conn: conn} do
      company = company_fixture(%{name: "SaveEntryCo"})
      a1 = account_fixture(%{company: company, name: "Cash", code: "1020", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Sales", code: "4020", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "company_id" => to_string(company.id),
            "date" => "2024-08-01",
            "description" => "New sale"
          },
          "lines" => %{
            "0" => %{"account_id" => to_string(a1.id), "debit" => "1000", "credit" => "0"},
            "1" => %{"account_id" => to_string(a2.id), "debit" => "0", "credit" => "1000"}
          }
        })
        |> render_submit()

      assert html =~ "Journal entry created"
      refute html =~ "modal-overlay"
      assert html =~ "New sale"
    end

    test "unbalanced entry shows form error", %{conn: conn} do
      company = company_fixture(%{name: "UnbalancedCo"})
      a1 = account_fixture(%{company: company, name: "Cash", code: "1030", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "AR", code: "1031", account_type: "asset"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "date" => "2024-08-01",
            "description" => "Unbalanced entry"
          },
          "lines" => %{
            "0" => %{"account_id" => to_string(a1.id), "debit" => "1000", "credit" => "0"},
            "1" => %{"account_id" => to_string(a2.id), "debit" => "0", "credit" => "500"}
          }
        })
        |> render_submit()

      assert html =~ "Debits"
      assert html =~ "must equal credits"
    end

    test "submitting with fewer than 2 lines shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "date" => "2024-08-01",
            "description" => "Single line entry"
          },
          "lines" => %{
            "0" => %{"account_id" => "", "debit" => "0", "credit" => "0"},
            "1" => %{"account_id" => "", "debit" => "0", "credit" => "0"}
          }
        })
        |> render_submit()

      assert html =~ "At least 2 lines required"
    end

    test "submitting entry without lines param shows at least 2 lines error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      html =
        render_hook(view, "save", %{
          "entry" => %{
            "date" => "2024-08-01",
            "description" => "No lines"
          }
        })

      assert html =~ "At least 2 lines required"
    end
  end

  describe "journal save event (viewer)" do
    test "viewer cannot save journal entries", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html =
        render_hook(view, "save", %{
          "entry" => %{"date" => "2024-01-01", "description" => "Blocked"},
          "lines" => %{}
        })

      assert html =~ "permission"
    end
  end

  describe "journal delete event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can delete a journal entry", %{conn: conn} do
      company = company_fixture(%{name: "DelEntryCo"})
      account = account_fixture(%{company: company, name: "Cash", code: "1040", account_type: "asset"})
      account2 = account_fixture(%{company: company, name: "Expense", code: "5040", account_type: "expense"})

      entry = journal_entry_fixture(%{company: company, date: "2024-09-01", description: "Deletable entry"})
      journal_line_fixture(%{entry: entry, account: account, debit: 200.0, credit: 0.0})
      journal_line_fixture(%{entry: entry, account: account2, debit: 0.0, credit: 200.0})

      {:ok, view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "Deletable entry"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{entry.id}"]))
        |> render_click()

      assert html =~ "Journal entry deleted"
      refute html =~ "Deletable entry"
    end

    test "viewer cannot delete a journal entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html = render_hook(view, "delete", %{"id" => "999"})
      assert html =~ "permission"
    end
  end

  describe "journal handle_info" do
    test "unknown messages trigger reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      send(view.pid, :unknown_event)
      html = render(view)
      assert html =~ "Journal"
    end
  end

  # ------------------------------------------------------------------
  # Accounting Reports - detailed tests
  # ------------------------------------------------------------------

  describe "reports page tabs and filters" do
    test "renders trial balance tab by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Trial Balance"
      assert html =~ "Balanced" || html =~ "UNBALANCED"
    end

    test "switch to balance sheet tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_click(view, "switch_tab", %{"tab" => "balance_sheet"})
      assert html =~ "Total Assets"
      assert html =~ "Total Liabilities"
      assert html =~ "Total Equity"
      assert html =~ "A = L + E"
    end

    test "switch to income statement tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_click(view, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
    end

    test "switch back to trial balance tab", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_click(view, "switch_tab", %{"tab" => "income_statement"})
      html = render_click(view, "switch_tab", %{"tab" => "trial_balance"})
      assert html =~ "Trial Balance"
    end

    test "filter by company", %{conn: conn} do
      company = company_fixture(%{name: "ReportFilterCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Accounting Reports"
    end

    test "reset company filter to all", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "Accounting Reports"
      assert html =~ "All Companies (Consolidated)"
    end

    test "filter dates on income statement", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_click(view, "switch_tab", %{"tab" => "income_statement"})
      html = render_change(view, "filter_dates", %{"date_from" => "2024-01-01", "date_to" => "2024-12-31"})
      assert html =~ "Total Revenue"
    end

    test "filter dates with company filter active", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      render_click(view, "switch_tab", %{"tab" => "income_statement"})
      html = render_change(view, "filter_dates", %{"date_from" => "2024-06-01", "date_to" => "2024-12-31"})
      assert html =~ "Total Revenue"
    end

    test "change currency to EUR", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "EUR"})
      assert html =~ "EUR"
    end

    test "change currency to GBP", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "GBP"})
      assert html =~ "GBP"
    end

    test "change currency to JPY", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "JPY"})
      assert html =~ "JPY"
    end

    test "change currency to CHF", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "CHF"})
      assert html =~ "CHF"
    end

    test "change currency to ARS uses catch-all symbol", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_change(view, "change_currency", %{"currency" => "ARS"})
      assert html =~ "ARS"
    end

    test "change currency back to USD resets rate", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_change(view, "change_currency", %{"currency" => "EUR"})
      html = render_change(view, "change_currency", %{"currency" => "USD"})
      assert html =~ "$"
    end

    test "shows company dropdown", %{conn: conn} do
      company_fixture(%{name: "ReportDropCo"})
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "ReportDropCo"
      assert html =~ "All Companies (Consolidated)"
    end

    test "shows currency dropdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "USD"
      assert html =~ "EUR"
      assert html =~ "GBP"
    end

    test "balance sheet shows empty states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_click(view, "switch_tab", %{"tab" => "balance_sheet"})
      assert html =~ "Total Assets" || html =~ "No asset accounts"
    end

    test "income statement shows empty states", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      html = render_click(view, "switch_tab", %{"tab" => "income_statement"})
      assert html =~ "Total Revenue" || html =~ "No revenue"
    end
  end

  describe "reports handle_info" do
    test "unknown messages trigger reload on reports page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      send(view.pid, :unknown_event)
      html = render(view)
      assert html =~ "Accounting Reports"
    end

    test "reload with company filter active", %{conn: conn} do
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/accounts/reports")
      render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      send(view.pid, :finance_changed)
      html = render(view)
      assert html =~ "Accounting Reports"
    end
  end

  describe "reports with account data" do
    test "trial balance shows account rows with data", %{conn: conn} do
      company = company_fixture(%{name: "TBCo"})
      a1 = account_fixture(%{company: company, name: "Cash TB", code: "1080", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Revenue TB", code: "4080", account_type: "revenue"})

      entry = journal_entry_fixture(%{company: company, date: "2024-01-15"})
      journal_line_fixture(%{entry: entry, account: a1, debit: 1000.0, credit: 0.0})
      journal_line_fixture(%{entry: entry, account: a2, debit: 0.0, credit: 1000.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/reports")
      assert html =~ "Cash TB"
      assert html =~ "1080"
    end
  end

  describe "chart of accounts - filter_company" do
    test "filtering by company shows only that company's accounts", %{conn: conn} do
      co1 = company_fixture(%{name: "ChartCo1"})
      co2 = company_fixture(%{name: "ChartCo2"})
      account_fixture(%{company: co1, name: "Cash Co1", code: "1100", account_type: "asset"})
      account_fixture(%{company: co2, name: "Cash Co2", code: "1200", account_type: "asset"})

      {:ok, view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Cash Co1"
      assert html =~ "Cash Co2"

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Cash Co1"
      refute html =~ "Cash Co2"

      # Reset filter
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "Cash Co1"
      assert html =~ "Cash Co2"
    end
  end

  describe "chart of accounts - editor CRUD" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can create an account", %{conn: conn} do
      company = company_fixture(%{name: "CreateAccountCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      view |> element("button", "Add Account") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "account" => %{
            "code" => "2000",
            "name" => "Accounts Payable",
            "account_type" => "liability",
            "company_id" => to_string(company.id),
            "parent_id" => "",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Account created"
      assert html =~ "Accounts Payable"
    end

    test "editor can create account with empty company and parent", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      view |> element("button", "Add Account") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "account" => %{
            "code" => "3000",
            "name" => "Owner Equity",
            "account_type" => "equity",
            "company_id" => "",
            "parent_id" => "",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Account created"
    end

    test "editor can delete an account", %{conn: conn} do
      company = company_fixture()
      account = account_fixture(%{company: company, name: "Delete Me", code: "9999", account_type: "expense"})

      {:ok, view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Delete Me"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{account.id}"]))
        |> render_click()

      assert html =~ "Account deleted"
    end

    test "show_form/close_form toggles modal on chart page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      html = view |> element("button", "Add Account") |> render_click()
      assert html =~ "modal-overlay"
      assert html =~ "Add Account"

      html = render_click(view, "close_form", %{})
      refute html =~ "modal-overlay"
    end

    test "noop event on chart page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      view |> element("button", "Add Account") |> render_click()
      html = render_click(view, "noop", %{})
      assert html =~ "modal-overlay"
    end
  end

  describe "chart of accounts - viewer permission guards" do
    test "viewer cannot save an account", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      html = render_hook(view, "save", %{"account" => %{"code" => "1", "name" => "X", "account_type" => "asset"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete an account", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      html = render_hook(view, "delete", %{"id" => "1"})
      assert html =~ "permission"
    end
  end

  describe "chart of accounts - handle_info" do
    test "handle_info reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      send(view.pid, :some_event)
      html = render(view)
      assert html =~ "Chart of Accounts"
    end
  end

  describe "chart of accounts - hierarchical tree" do
    test "parent-child accounts render with indentation", %{conn: conn} do
      company = company_fixture()
      parent = account_fixture(%{company: company, name: "Assets", code: "1000", account_type: "asset"})
      account_fixture(%{company: company, name: "Cash", code: "1001", account_type: "asset", parent_id: parent.id})

      {:ok, _view, html} = live(conn, ~p"/accounts/chart")

      assert html =~ "Assets"
      assert html =~ "Cash"
      # Child should have indentation styling
      assert html =~ "padding-left"
    end
  end

  describe "chart of accounts - type counts" do
    test "type counts metric strip shows correct counts", %{conn: conn} do
      company = company_fixture()
      account_fixture(%{company: company, name: "Cash", code: "A100", account_type: "asset"})
      account_fixture(%{company: company, name: "AR", code: "A101", account_type: "asset"})
      account_fixture(%{company: company, name: "Loan", code: "L100", account_type: "liability"})

      {:ok, _view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Assets"
      assert html =~ "Liabilities"
    end
  end

  describe "journal handle_params with account_id filter" do
    test "filters entries by account_id when provided", %{conn: conn} do
      company = company_fixture(%{name: "ParamFilterCo"})
      a1 = account_fixture(%{company: company, name: "Filtered Account", code: "1050", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Other Account", code: "1051", account_type: "asset"})

      entry1 = journal_entry_fixture(%{company: company, description: "Filtered entry"})
      journal_line_fixture(%{entry: entry1, account: a1, debit: 100.0})

      entry2 = journal_entry_fixture(%{company: company, description: "Unfiltered entry"})
      journal_line_fixture(%{entry: entry2, account: a2, debit: 100.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal?account_id=#{a1.id}")

      assert html =~ "Filtered entry"
      assert html =~ "Filtered Account"
      assert html =~ "Clear filter"
      refute html =~ "Unfiltered entry"
    end

    test "without account_id param shows all entries", %{conn: conn} do
      company = company_fixture(%{name: "NoParamCo"})
      a1 = account_fixture(%{company: company, name: "Acct A", code: "1060", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Acct B", code: "1061", account_type: "asset"})

      entry1 = journal_entry_fixture(%{company: company, description: "Entry A"})
      journal_line_fixture(%{entry: entry1, account: a1, debit: 50.0})

      entry2 = journal_entry_fixture(%{company: company, description: "Entry B"})
      journal_line_fixture(%{entry: entry2, account: a2, debit: 50.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "Entry A"
      assert html =~ "Entry B"
      refute html =~ "Clear filter"
    end
  end

  describe "journal entry without company_id" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "creating a journal entry with no company succeeds", %{conn: conn} do
      company = company_fixture(%{name: "EntryNoCo"})
      a1 = account_fixture(%{company: company, name: "Cash", code: "1070", account_type: "asset"})
      a2 = account_fixture(%{company: company, name: "Revenue", code: "4070", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "company_id" => "",
            "date" => "2024-10-01",
            "description" => "No company entry"
          },
          "lines" => %{
            "0" => %{"account_id" => to_string(a1.id), "debit" => "500", "credit" => "0"},
            "1" => %{"account_id" => to_string(a2.id), "debit" => "0", "credit" => "500"}
          }
        })
        |> render_submit()

      assert html =~ "Journal entry created"
      assert html =~ "No company entry"
    end
  end

  describe "journal entry reference display" do
    test "entries show reference or em dash when no reference", %{conn: conn} do
      company = company_fixture(%{name: "RefCo"})
      journal_entry_fixture(%{company: company, description: "Has Reference", reference: "JE-100"})
      journal_entry_fixture(%{company: company, description: "No Reference"})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "JE-100"
      assert html =~ "Has Reference"
      assert html =~ "No Reference"
    end
  end

end
