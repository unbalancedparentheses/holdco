defmodule HoldcoWeb.TransactionsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /transactions" do
    test "renders transactions page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Transactions"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "page-title"
      assert html =~ "transactions across all entities"
    end

    test "renders metrics strip with inflows and outflows", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "metrics-strip"
      assert html =~ "Total Inflows"
      assert html =~ "Total Outflows"
    end

    test "transactions page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      # Transactions is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Transactions"
    end

    test "shows export button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Export CSV"
    end

    test "shows add button for editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/transactions")

      assert html =~ "Add Transaction"
    end
  end

  describe "GET /transactions/:id" do
    test "renders show page with transaction details", %{conn: conn} do
      company = company_fixture(%{name: "ShowTxnCo"})

      transaction =
        transaction_fixture(%{
          company: company,
          transaction_type: "debit",
          description: "Office rent payment",
          amount: -2500.0,
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

    test "shows metrics strip", %{conn: conn} do
      transaction =
        transaction_fixture(%{
          transaction_type: "credit",
          amount: 1000.0,
          currency: "USD",
          date: "2024-03-01"
        })

      {:ok, _view, html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert html =~ "metrics-strip"
      assert html =~ "Amount"
      assert html =~ "Type"
      assert html =~ "Date"
    end

    test "shows back to transactions link", %{conn: conn} do
      transaction = transaction_fixture(%{description: "Nav transaction"})

      {:ok, _view, html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert html =~ "Back to Transactions"
      assert html =~ ~s(/transactions)
    end

    test "shows details section with description and counterparty", %{conn: conn} do
      transaction =
        transaction_fixture(%{
          description: "Wire transfer",
          counterparty: "Acme Corp"
        })

      {:ok, _view, html} = live(conn, ~p"/transactions/#{transaction.id}")

      assert html =~ "Details"
      assert html =~ "Description"
      assert html =~ "Wire transfer"
      assert html =~ "Counterparty"
      assert html =~ "Acme Corp"
    end
  end
end
