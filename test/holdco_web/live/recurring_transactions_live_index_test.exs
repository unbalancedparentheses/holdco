defmodule HoldcoWeb.RecurringTransactionsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Recurring Transactions page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/recurring-transactions")
      assert html =~ "Recurring Transactions"
      assert html =~ "Automate repetitive journal entries on a set schedule"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/recurring-transactions")
      assert html =~ "Total"
      assert html =~ "Active"
      assert html =~ "Inactive"
    end

    test "shows table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/recurring-transactions")
      assert html =~ "All Recurring Transactions"
      assert html =~ "Description"
      assert html =~ "Frequency"
      assert html =~ "Next Run"
    end

    test "shows empty state when no recurring transactions exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/recurring-transactions")
      assert html =~ "No recurring transactions defined."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/recurring-transactions")
      assert html =~ "All Companies"
    end
  end

  describe "show_form and close_form" do
    test "show_form opens the new transaction dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "show_form")
      assert html =~ "New Recurring Transaction"
      assert html =~ "Description *"
      assert html =~ "Frequency *"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter_company" do
    test "filtering by company updates the list", %{conn: conn} do
      company = company_fixture(%{name: "Filter Corp"})

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      # After filtering, the page still renders
      assert html =~ "All Recurring Transactions"
    end

    test "filtering with empty company_id shows all transactions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "All Recurring Transactions"
    end
  end

  describe "save (create)" do
    test "creating a recurring transaction with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "rt" => %{
            "company_id" => to_string(company.id),
            "description" => "Monthly Rent",
            "amount" => "5000",
            "currency" => "USD",
            "frequency" => "monthly",
            "start_date" => "2025-01-01",
            "next_run_date" => "2025-02-01"
          }
        })

      assert html =~ "Recurring transaction created"
      assert html =~ "Monthly Rent"
    end

    test "creating a recurring transaction with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "rt" => %{
            "description" => "",
            "amount" => "",
            "frequency" => ""
          }
        })

      assert html =~ "Failed to create recurring transaction"
    end
  end

  describe "edit and update" do
    test "edit event opens edit form with existing data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Editable RT",
          amount: 1000,
          frequency: "weekly",
          start_date: "2025-01-01",
          next_run_date: "2025-01-08"
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "edit", %{"id" => to_string(rt.id)})
      assert html =~ "Edit Recurring Transaction"
      assert html =~ "Editable RT"
    end

    test "updating a recurring transaction with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Old Description",
          amount: 1000,
          frequency: "weekly",
          start_date: "2025-01-01",
          next_run_date: "2025-01-08"
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      render_click(view, "edit", %{"id" => to_string(rt.id)})

      html =
        render_click(view, "update", %{
          "rt" => %{
            "company_id" => to_string(company.id),
            "description" => "Updated Description",
            "amount" => "2000",
            "frequency" => "monthly",
            "start_date" => "2025-01-01",
            "next_run_date" => "2025-02-01"
          }
        })

      assert html =~ "Recurring transaction updated"
      assert html =~ "Updated Description"
    end
  end

  describe "delete" do
    test "deleting a recurring transaction removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Doomed RT",
          amount: 500,
          frequency: "daily",
          start_date: "2025-01-01",
          next_run_date: "2025-01-02"
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      assert render(view) =~ "Doomed RT"

      html = render_click(view, "delete", %{"id" => to_string(rt.id)})
      assert html =~ "Recurring transaction deleted"
      refute html =~ "Doomed RT"
    end
  end

  describe "toggle_active" do
    test "toggling active status deactivates an active transaction", %{conn: conn} do
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Toggle RT",
          amount: 100,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-02-01",
          is_active: true
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "toggle_active", %{"id" => to_string(rt.id)})
      assert html =~ "Recurring transaction deactivated"
    end

    test "toggling active status activates an inactive transaction", %{conn: conn} do
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Inactive Toggle RT",
          amount: 100,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-02-01",
          is_active: false
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "toggle_active", %{"id" => to_string(rt.id)})
      assert html =~ "Recurring transaction activated"
    end
  end

  describe "run_now" do
    test "run_now without configured accounts shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "No Accounts RT",
          amount: 100,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-02-01"
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "run_now", %{"id" => to_string(rt.id)})
      assert html =~ "Cannot run: debit and credit accounts must be configured"
    end

    test "run_now with configured accounts generates journal entry", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      debit_account = account_fixture(%{company: company, account_type: "asset", code: "1001", name: "Cash"})
      credit_account = account_fixture(%{company: company, account_type: "liability", code: "2001", name: "Rent Payable"})

      {:ok, rt} =
        Holdco.Finance.create_recurring_transaction(%{
          company_id: company.id,
          description: "Runnable RT",
          amount: 1000,
          frequency: "monthly",
          start_date: "2025-01-01",
          next_run_date: "2025-02-01",
          debit_account_id: debit_account.id,
          credit_account_id: credit_account.id
        })

      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "run_now", %{"id" => to_string(rt.id)})
      assert html =~ "Transaction generated and next run date advanced"
    end
  end

  describe "noop" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")
      html = render_click(view, "noop")
      assert html =~ "Recurring Transactions"
    end
  end

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/recurring-transactions")

      company = company_fixture()

      Holdco.Finance.create_recurring_transaction(%{
        company_id: company.id,
        description: "PubSub RT",
        amount: 100,
        frequency: "daily",
        start_date: "2025-01-01",
        next_run_date: "2025-01-02"
      })

      send(view.pid, {:finance_changed, %{}})
      html = render(view)
      assert html =~ "PubSub RT"
    end
  end
end
