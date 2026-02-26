defmodule HoldcoWeb.BankAccountsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /bank-accounts" do
    test "renders bank accounts page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Bank Accounts"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "page-title"
    end

    test "bank accounts page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      # Bank Accounts is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Bank Accounts"
    end
  end

  describe "GET /bank-accounts/:id" do
    test "renders show page with bank account details", %{conn: conn} do
      company = company_fixture(%{name: "ShowBankCo"})

      account =
        bank_account_fixture(%{
          company: company,
          bank_name: "First National Bank",
          account_number: "1234567890",
          currency: "EUR",
          balance: 50000.0,
          account_type: "savings"
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "First National Bank"
      assert html =~ "1234567890"
      assert html =~ "EUR"
      assert html =~ "50,000"
      assert html =~ "savings"
      assert html =~ "Bank account details"
    end

    test "shows company link when company exists", %{conn: conn} do
      company = company_fixture(%{name: "LinkedBankCompany"})
      account = bank_account_fixture(%{company: company, bank_name: "Company Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "LinkedBankCompany"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "shows metrics strip", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "Metrics Bank",
          currency: "USD",
          balance: 12345.0,
          account_type: "operating"
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "metrics-strip"
      assert html =~ "Balance"
      assert html =~ "Currency"
      assert html =~ "Type"
    end

    test "shows back to accounts link", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "Nav Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Back to Accounts"
      assert html =~ ~s(/bank-accounts)
    end

    test "shows related transactions section", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "Txn Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Related Transactions"
    end
  end
end
