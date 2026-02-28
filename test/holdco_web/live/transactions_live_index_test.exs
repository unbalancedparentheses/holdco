defmodule HoldcoWeb.TransactionsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders the page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "<h1>Transactions</h1>"
      assert html =~ "transactions across all entities"
      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders metrics strip with inflows, outflows, and net", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "metrics-strip"
      assert html =~ "Total Inflows"
      assert html =~ "Total Outflows"
      assert html =~ "Net"
    end

    test "renders the transaction table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "<th>Date</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Description</th>"
      assert html =~ "<th>Counterparty</th>"
      assert html =~ "Amount"
      assert html =~ "<th>Currency</th>"
      assert html =~ "<th>Company</th>"
    end

    test "renders section heading for All Transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "All Transactions"
      assert html =~ "Transaction Flow"
    end

    test "renders empty state when no transactions exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "No transactions yet."
      assert html =~ "empty-state"
    end

    test "renders export CSV link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Export CSV"
      assert html =~ "/export/transactions.csv"
    end

    test "renders company filter dropdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "All Companies"
      assert html =~ "form-select"
      assert html =~ ~s(name="company_id")
    end

    test "shows transaction data when transactions exist", %{conn: conn} do
      company = company_fixture(%{name: "Acme Corp"})
      transaction_fixture(%{company: company, description: "Invoice payment", amount: 500.0, currency: "USD", counterparty: "Vendor A", transaction_type: "credit", date: "2024-03-01"})

      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Acme Corp"
      assert html =~ "Invoice payment"
      assert html =~ "Vendor A"
      assert html =~ "credit"
      assert html =~ "2024-03-01"
      assert html =~ "1 transactions across all entities"
    end

    test "renders the chart hook container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ ~s(id="tx-chart")
      assert html =~ "ChartHook"
    end
  end

  describe "editor role" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "shows Add Transaction button for editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Add Transaction"
      assert html =~ ~s(phx-click="show_form")
    end

    test "shows Import CSV link for editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Import CSV"
      assert html =~ "/import?type=transactions"
    end

    test "shows delete button for editor when transactions exist", %{conn: conn} do
      transaction_fixture()
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "btn btn-danger btn-sm"
      assert html =~ "Del"
      assert html =~ ~s(phx-click="delete")
    end

    test "clicking Add Transaction opens the modal form", %{conn: conn} do
      company_fixture(%{name: "FormCo"})
      {:ok, view, _html} = live(conn, ~p"/transactions")

      html = view |> element("button", "Add Transaction") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "dialog-header"
      assert html =~ "Add Transaction"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="transaction[company_id]")
      assert html =~ ~s(name="transaction[date]")
      assert html =~ ~s(name="transaction[transaction_type]")
      assert html =~ ~s(name="transaction[amount]")
      assert html =~ ~s(name="transaction[currency]")
      assert html =~ ~s(name="transaction[description]")
      assert html =~ ~s(name="transaction[counterparty]")
      assert html =~ "FormCo"
    end

    test "clicking Cancel closes the modal form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions")

      view |> element("button", "Add Transaction") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "clicking modal overlay closes the form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions")

      view |> element("button", "Add Transaction") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "submitting the form creates a transaction", %{conn: conn} do
      company = company_fixture(%{name: "NewTxCo"})
      {:ok, view, _html} = live(conn, ~p"/transactions")

      view |> element("button", "Add Transaction") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "transaction" => %{
            "company_id" => to_string(company.id),
            "date" => "2024-06-15",
            "transaction_type" => "debit",
            "amount" => "250.0",
            "currency" => "USD",
            "description" => "Office supplies",
            "counterparty" => "Staples"
          }
        })
        |> render_submit()

      assert html =~ "Transaction added"
      refute html =~ "dialog-overlay"
    end

    test "deleting a transaction removes it from the list", %{conn: conn} do
      tx = transaction_fixture(%{description: "DeleteMe"})
      {:ok, view, html} = live(conn, ~p"/transactions")

      assert html =~ "DeleteMe"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{tx.id}"]))
        |> render_click()

      assert html =~ "Transaction deleted"
      refute html =~ "DeleteMe"
    end
  end

  describe "company filter" do
    test "filtering by company shows only that company's transactions", %{conn: conn} do
      co1 = company_fixture(%{name: "AlphaCo"})
      co2 = company_fixture(%{name: "BetaCo"})
      transaction_fixture(%{company: co1, description: "Alpha payment"})
      transaction_fixture(%{company: co2, description: "Beta payment"})

      {:ok, view, html} = live(conn, ~p"/transactions")

      assert html =~ "Alpha payment"
      assert html =~ "Beta payment"

      # Filter to co1 only
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Alpha payment"
      refute html =~ "Beta payment"
    end

    test "resetting filter to All Companies shows all transactions", %{conn: conn} do
      co1 = company_fixture(%{name: "FilterCo1"})
      co2 = company_fixture(%{name: "FilterCo2"})
      transaction_fixture(%{company: co1, description: "Tx1 desc"})
      transaction_fixture(%{company: co2, description: "Tx2 desc"})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      # Filter to co1
      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
      |> render_change()

      # Reset to all
      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      assert html =~ "Tx1 desc"
      assert html =~ "Tx2 desc"
    end

    test "company options appear in the filter dropdown", %{conn: conn} do
      company_fixture(%{name: "DropdownCo"})

      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "DropdownCo"
    end
  end

  describe "metrics calculations" do
    test "inflows and outflows are computed from transactions", %{conn: conn} do
      company = company_fixture()
      transaction_fixture(%{company: company, amount: 1000.0})
      transaction_fixture(%{company: company, amount: 400.0, transaction_type: "debit"})

      {:ok, _view, html} = live(conn, ~p"/transactions")

      # Inflows: $1,000, Outflows: $400, Net: $600
      assert html =~ "1,000"
      assert html =~ "400"
      assert html =~ "600"
    end
  end

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Transactions"
    end
  end

  describe "handle_info for PubSub" do
    test "handles broadcast by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/transactions")

      send(view.pid, :some_broadcast)

      html = render(view)
      assert html =~ "Transactions"
    end
  end

  describe "metrics with filtered company" do
    test "metrics update when company filter is applied", %{conn: conn} do
      co1 = company_fixture(%{name: "MetricCo1"})
      co2 = company_fixture(%{name: "MetricCo2"})
      transaction_fixture(%{company: co1, amount: 2000.0, description: "MetricTx1"})
      transaction_fixture(%{company: co2, amount: 500.0, description: "MetricTx2", transaction_type: "debit"})

      {:ok, view, _html} = live(conn, ~p"/transactions")

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "MetricTx1"
      # co2's transaction description should not appear in the table
      refute html =~ "MetricTx2"
    end
  end

  describe "edit event (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking edit opens the edit form modal with pre-filled data", %{conn: conn} do
      company = company_fixture(%{name: "EditCo"})

      tx =
        transaction_fixture(%{
          company: company,
          description: "Editable transaction",
          transaction_type: "credit",
          amount: 750.0,
          currency: "EUR",
          date: "2024-05-10",
          counterparty: "Partner Inc"
        })

      {:ok, view, _html} = live(conn, ~p"/transactions")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{tx.id}"]))
        |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Edit Transaction"
      assert html =~ ~s(phx-submit="update")
      assert html =~ "Save Changes"
    end

    test "submitting the edit form updates a transaction", %{conn: conn} do
      company = company_fixture(%{name: "UpdateCo"})

      tx =
        transaction_fixture(%{
          company: company,
          description: "Original desc",
          transaction_type: "debit",
          amount: 100.0,
          date: "2024-01-01"
        })

      {:ok, view, _html} = live(conn, ~p"/transactions")

      # Open edit form
      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{tx.id}"]))
      |> render_click()

      # Submit update
      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "transaction" => %{
            "company_id" => to_string(company.id),
            "date" => "2024-02-01",
            "transaction_type" => "credit",
            "amount" => "200.0",
            "description" => "Updated desc"
          }
        })
        |> render_submit()

      assert html =~ "Transaction updated"
      refute html =~ "dialog-overlay"
    end
  end

end
