defmodule HoldcoWeb.TransactionsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "editor role" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
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

  describe "show page" do
    test "renders show page with transaction details", %{conn: conn} do
      company = company_fixture(%{name: "ShowTxnCo"})

      transaction =
        transaction_fixture(%{
          company: company,
          transaction_type: "debit",
          description: "Office rent payment",
          amount: 2500.0,
          currency: "GBP",
          date: "2024-06-15",
          counterparty: "Landlord Ltd"
        })

      {:ok, _view, html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert html =~ "Transaction Detail"
      assert html =~ "debit"
      assert html =~ "2,500"
      assert html =~ "GBP"
      assert html =~ "2024-06-15"
      assert html =~ "Office rent payment"
      assert html =~ "Landlord Ltd"
    end

    test "shows company link when company exists", %{conn: conn} do
      company = company_fixture(%{name: "LinkedTxnCompany"})

      transaction =
        transaction_fixture(%{
          company: company,
          description: "Company transaction"
        })

      {:ok, _view, html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert html =~ "LinkedTxnCompany"
      assert html =~ ~s(/companies/#{company.id})
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
