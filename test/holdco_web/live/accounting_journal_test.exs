defmodule HoldcoWeb.AccountingJournalTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "<h1>Journal Entries</h1>"
      assert html =~ "Double-entry bookkeeping records"
      assert html =~ "page-title-rule"
    end

    test "renders company filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "All Companies"
      assert html =~ ~s(phx-change="filter_company")
    end

    test "renders table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "All Entries"
      assert html =~ "Date"
      assert html =~ "Reference"
      assert html =~ "Description"
      assert html =~ "Debit"
      assert html =~ "Credit"
      assert html =~ "Lines"
    end

    test "renders empty state when no entries", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "No journal entries yet."
    end

    test "renders existing journal entries", %{conn: conn} do
      company = company_fixture(%{name: "JournalCo"})
      je = journal_entry_fixture(%{company_id: company.id, date: "2025-01-15", description: "Office rent", reference: "JE-001"})
      acct = account_fixture(%{company_id: company.id, code: "6000", name: "Rent Expense", account_type: "expense"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct.id, debit: 5000.0, credit: 0.0})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "2025-01-15"
      assert html =~ "Office rent"
      assert html =~ "JE-001"
    end

    test "viewer cannot see New Journal Entry button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      refute html =~ "New Journal Entry"
    end

    test "editor sees New Journal Entry button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "New Journal Entry"
    end
  end

  # ── Filter Company ──────────────────────────────────────

  describe "filter_company event" do
    test "filters journal entries by company", %{conn: conn} do
      c1 = company_fixture(%{name: "JCo1"})
      c2 = company_fixture(%{name: "JCo2"})
      journal_entry_fixture(%{company_id: c1.id, date: "2025-01-01", description: "Entry for JCo1"})
      journal_entry_fixture(%{company_id: c2.id, date: "2025-02-01", description: "Entry for JCo2"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(c1.id)})
        |> render_change()

      assert html =~ "Entry for JCo1"
      refute html =~ "Entry for JCo2"
    end
  end

  # ── Toggle Entry (Expand/Collapse) ──────────────────────

  describe "toggle_entry event" do
    test "expands a journal entry to show lines", %{conn: conn} do
      company = company_fixture()
      je = journal_entry_fixture(%{company_id: company.id, date: "2025-03-01", description: "Toggle test"})
      acct = account_fixture(%{company_id: company.id, code: "1000", name: "Cash", account_type: "asset"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct.id, debit: 1000.0, credit: 0.0})

      {:ok, view, html} = live(conn, ~p"/accounts/journal")
      # Entry row is present but lines are collapsed
      assert html =~ "Toggle test"

      # Click to expand - the entry row has phx-click="toggle_entry"
      html = view |> element(~s(tr[phx-click="toggle_entry"][phx-value-id="#{je.id}"])) |> render_click()

      # After expansion, line details should be visible
      assert html =~ "Cash"
      assert html =~ "1000"
    end

    test "collapsing hides the lines", %{conn: conn} do
      company = company_fixture()
      je = journal_entry_fixture(%{company_id: company.id, date: "2025-03-01", description: "Collapse test"})
      acct = account_fixture(%{company_id: company.id, code: "2000", name: "Bank", account_type: "asset"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct.id, debit: 500.0, credit: 0.0})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      # Expand
      view |> element(~s(tr[phx-click="toggle_entry"][phx-value-id="#{je.id}"])) |> render_click()

      # Collapse
      html = view |> element(~s(tr[phx-click="toggle_entry"][phx-value-id="#{je.id}"])) |> render_click()

      # Lines should no longer be visible
      # The expanded line rows have a distinct background style
      refute html =~ "background: var(--color-bg-alt"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens New Journal Entry modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html = view |> element("button", "New Journal Entry") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "New Journal Entry"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="entry[date]")
      assert html =~ ~s(name="entry[reference]")
      assert html =~ ~s(name="entry[description]")
      assert html =~ ~s(name="entry[company_id]")
    end

    test "form shows line rows", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      html = view |> element("button", "New Journal Entry") |> render_click()

      # Default 2 lines
      assert html =~ ~s(name="lines[0][account_id]")
      assert html =~ ~s(name="lines[1][account_id]")
      assert html =~ ~s(name="lines[0][debit]")
      assert html =~ ~s(name="lines[0][credit]")
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Add Line ────────────────────────────────────────────

  describe "add_line event" do
    test "adds another line row to the form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()

      # Before: 2 lines (0 and 1)
      refute render(view) =~ ~s(name="lines[2][account_id]")

      # Click add line
      html = view |> element(~s(button[phx-click="add_line"])) |> render_click()

      assert html =~ ~s(name="lines[2][account_id]")
    end
  end

  # ── Save Journal Entry ──────────────────────────────────

  describe "save event" do
    test "creates a journal entry with balanced lines", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SaveJCo"})
      acct1 = account_fixture(%{company_id: company.id, code: "1000", name: "Cash", account_type: "asset"})
      acct2 = account_fixture(%{company_id: company.id, code: "4000", name: "Revenue", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")
      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "company_id" => company.id,
            "date" => "2025-06-01",
            "reference" => "JE-100",
            "description" => "Test balanced entry"
          },
          "lines" => %{
            "0" => %{"account_id" => acct1.id, "debit" => "1000", "credit" => "0"},
            "1" => %{"account_id" => acct2.id, "debit" => "0", "credit" => "1000"}
          }
        })
        |> render_submit()

      assert html =~ "Journal entry created"
      assert html =~ "Test balanced entry"
      refute html =~ "dialog-overlay"
    end

    test "shows error when debits do not equal credits", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      acct1 = account_fixture(%{company_id: company.id, code: "1000", name: "Cash", account_type: "asset"})
      acct2 = account_fixture(%{company_id: company.id, code: "4000", name: "Revenue", account_type: "revenue"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")
      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "date" => "2025-06-01",
            "description" => "Unbalanced"
          },
          "lines" => %{
            "0" => %{"account_id" => acct1.id, "debit" => "1000", "credit" => "0"},
            "1" => %{"account_id" => acct2.id, "debit" => "0", "credit" => "500"}
          }
        })
        |> render_submit()

      assert html =~ "Debits"
      assert html =~ "must equal credits"
    end

    test "shows error when less than 2 lines", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")
      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "date" => "2025-06-01",
            "description" => "One line only"
          },
          "lines" => %{
            "0" => %{"account_id" => "", "debit" => "0", "credit" => "0"},
            "1" => %{"account_id" => "", "debit" => "0", "credit" => "0"}
          }
        })
        |> render_submit()

      assert html =~ "At least 2 lines required"
    end

    test "viewer cannot save a journal entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      render_hook(view, "save", %{"entry" => %{"date" => "2025-01-01", "description" => "Blocked"}})
      assert render(view) =~ "permission"
    end
  end

  # ── Delete Journal Entry ────────────────────────────────

  describe "delete event" do
    test "deletes a journal entry and its lines", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      je = journal_entry_fixture(%{company_id: company.id, date: "2025-04-01", description: "Delete me entry"})
      acct = account_fixture(%{company_id: company.id, code: "1000", name: "Cash", account_type: "asset"})
      journal_line_fixture(%{entry_id: je.id, account_id: acct.id, debit: 100.0})

      {:ok, view, html} = live(conn, ~p"/accounts/journal")
      assert html =~ "Delete me entry"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{je.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Journal entry deleted"
      refute html =~ "Delete me entry"
    end

    test "viewer cannot delete a journal entry", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      render_hook(view, "delete", %{"id" => "1"})
      assert render(view) =~ "permission"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Journal Entries"
    end
  end

  # ── Handle Info (PubSub) ──────────────────────────────

  describe "handle_info for PubSub" do
    test "handles broadcast by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Journal Entries"
    end
  end

  # ── Close form via overlay ────────────────────────────

  describe "close form via overlay" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking overlay closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      view |> element("button", "New Journal Entry") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Save with no lines param ──────────────────────────

  describe "save with no lines submitted" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "submitting entry without lines key shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/journal")
      view |> element("button", "New Journal Entry") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "entry" => %{
            "date" => "2025-06-01",
            "description" => "No lines entry"
          }
        })
        |> render_submit()

      assert html =~ "At least 2 lines required"
    end
  end

  # ── Filter to all companies ───────────────────────────

  describe "filter_company reset" do
    test "resetting company filter shows all entries", %{conn: conn} do
      c1 = company_fixture(%{name: "JReset1"})
      c2 = company_fixture(%{name: "JReset2"})
      journal_entry_fixture(%{company_id: c1.id, date: "2025-01-01", description: "JEntry1"})
      journal_entry_fixture(%{company_id: c2.id, date: "2025-02-01", description: "JEntry2"})

      {:ok, view, _html} = live(conn, ~p"/accounts/journal")

      # Filter to c1
      view
      |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(c1.id)})
      |> render_change()

      # Reset to all
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "JEntry1"
      assert html =~ "JEntry2"
    end
  end

  # ── Entry with reference shows correctly ──────────────

  describe "entry display details" do
    test "entry without reference shows em dash", %{conn: conn} do
      journal_entry_fixture(%{date: "2025-05-01", description: "No ref entry", reference: nil})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "No ref entry"
    end

    test "viewer cannot see delete button", %{conn: conn} do
      journal_entry_fixture(%{date: "2025-05-01", description: "ViewerTestEntry"})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "ViewerTestEntry"
      refute html =~ "btn btn-danger btn-sm"
    end

    test "editor sees delete button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      journal_entry_fixture(%{date: "2025-05-01", description: "EditorDeleteEntry"})

      {:ok, _view, html} = live(conn, ~p"/accounts/journal")

      assert html =~ "EditorDeleteEntry"
      assert html =~ "btn btn-danger btn-sm"
    end
  end
end
