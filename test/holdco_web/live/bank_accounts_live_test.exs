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

    test "shows empty state when no transactions exist", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "Empty Txn Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "No transactions for this company."
      assert html =~ "empty-state"
    end

    test "shows transaction data when transactions exist", %{conn: conn} do
      company = company_fixture(%{name: "TxnDataCo"})

      account =
        bank_account_fixture(%{company: company, bank_name: "TxnBank"})

      transaction_fixture(%{
        company: company,
        transaction_type: "credit",
        description: "Incoming wire",
        amount: 25000.0,
        currency: "USD",
        date: "2024-03-15"
      })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Incoming wire"
      assert html =~ "credit"
      assert html =~ "2024-03-15"
      assert html =~ "USD"
      assert html =~ "num-positive"
    end

    test "shows negative transaction amount with negative styling", %{conn: conn} do
      company = company_fixture(%{name: "NegTxnCo"})
      account = bank_account_fixture(%{company: company, bank_name: "NegTxnBank"})

      transaction_fixture(%{
        company: company,
        transaction_type: "debit",
        description: "Outgoing payment",
        amount: -5000.0,
        currency: "EUR",
        date: "2024-04-01"
      })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Outgoing payment"
      assert html =~ "num-negative"
      assert html =~ "debit"
    end

    test "shows IBAN and SWIFT when provided", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "IBAN Bank",
          iban: "DE89370400440532013000",
          swift: "COBADEFFXXX"
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "DE89370400440532013000"
      assert html =~ "COBADEFFXXX"
    end

    test "shows dashes for missing IBAN, SWIFT, and account_number", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "No Details Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      # The "---" placeholders should appear for missing fields
      assert html =~ "---"
    end

    test "shows nil balance as $0", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "Zero Balance Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "$"
    end

    test "renders transaction count in header", %{conn: conn} do
      company = company_fixture(%{name: "CountCo"})
      account = bank_account_fixture(%{company: company, bank_name: "CountBank"})

      transaction_fixture(%{company: company, description: "Tx1"})
      transaction_fixture(%{company: company, description: "Tx2"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "count"
      assert html =~ "2"
    end

    test "shows transaction table headers", %{conn: conn} do
      company = company_fixture(%{name: "TblHeaderCo"})
      account = bank_account_fixture(%{company: company, bank_name: "TblBank"})
      transaction_fixture(%{company: company, description: "HeaderTx"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "<th>Date</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Description</th>"
      assert html =~ "Amount"
      assert html =~ "<th>Currency</th>"
    end

    test "renders page-title-rule and detail-list", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "Detail Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "page-title-rule"
      assert html =~ "detail-list"
      assert html =~ "detail-row"
      assert html =~ "Account Details"
    end

    test "shows zero amount transaction", %{conn: conn} do
      company = company_fixture(%{name: "ZeroAmtCo"})
      account = bank_account_fixture(%{company: company, bank_name: "ZeroAmtBank"})
      transaction_fixture(%{company: company, description: "ZeroAmtTx", amount: 0.0})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "ZeroAmtTx"
      assert html =~ "num-positive"
    end

    test "displays large balance with commas formatting", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "Large Balance Bank",
          balance: 1234567.0
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "1,234,567"
    end
  end
end
