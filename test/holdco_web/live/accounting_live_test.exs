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

  describe "integrations page - detailed" do
    test "shows QuickBooks Online section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "QuickBooks Online"
    end

    test "shows Connect to QuickBooks when not connected", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connect to QuickBooks"
      assert html =~ "Disconnected"
    end

    test "shows Connected status when integration is connected", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected", "realm_id" => "123456"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Connected"
      assert html =~ "123456"
    end

    test "shows Sync Now button when connected", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Sync Now"
    end

    test "shows Disconnect button for editor when connected", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "Disconnect"
    end
  end

  describe "integrations - viewer permission guards" do
    test "viewer disconnect returns permission error", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = render_hook(view, "disconnect", %{})
      assert html =~ "permission"
    end

    test "viewer sync returns permission error", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = render_hook(view, "sync", %{})
      assert html =~ "permission"
    end
  end

  describe "integrations - editor disconnect" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can disconnect QuickBooks", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html = view |> element(~s(button[phx-click="disconnect"])) |> render_click()

      assert html =~ "QuickBooks disconnected"
      assert html =~ "Disconnected"
    end
  end

  describe "integrations - select_sync_company" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "select_sync_company updates selected company", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      company = company_fixture(%{name: "SyncTargetCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      html =
        view
        |> form(~s(form[phx-change="select_sync_company"]), %{"company_id" => to_string(company.id)})
        |> render_change()

      assert html =~ "SyncTargetCo"
    end
  end

  describe "integrations - unknown handle_info" do
    test "unknown messages reload integration state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/integrations")

      send(view.pid, :unknown_event)

      html = render(view)
      assert html =~ "QuickBooks Online"
    end
  end

  describe "integrations - company selector" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "company dropdown shows All Companies option when connected", %{conn: conn} do
      Holdco.Integrations.upsert_integration("quickbooks", %{"status" => "connected"})
      company_fixture(%{name: "DropdownCo"})

      {:ok, _view, html} = live(conn, ~p"/accounts/integrations")

      assert html =~ "All Companies"
      assert html =~ "DropdownCo"
    end
  end

  # ------------------------------------------------------------------
  # Journal Entries - detailed tests
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
  end
end
