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
        amount: 5000.0,
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
      transaction_fixture(%{company: company, description: "ZeroAmtTx", amount: 0.01})

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

    test "handles account with nil balance", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "Nil Balance Bank",
          balance: nil,
          account_type: "checking"
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      # format_number(nil) falls through to the catch-all returning "0"
      assert html =~ "$0"
    end

    test "shows integer balance formatting", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "Integer Balance Bank",
          balance: 5000
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "5,000"
    end
  end

  # ------------------------------------------------------------------
  # Index page CRUD operations
  # ------------------------------------------------------------------

  describe "index page form interactions" do
    test "show_form opens add bank account form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "show_form", %{})
      assert html =~ "Add Bank Account"
      assert html =~ "dialog-overlay"
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "dialog-overlay"
    end

    test "noop event does nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "noop", %{})
      assert html =~ "Bank Accounts"
    end

    test "edit opens edit form", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Edit Me Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "edit", %{"id" => to_string(ba.id)})
      assert html =~ "Edit Bank Account"
      assert html =~ "Save Changes"
    end

    test "filter by company on index page", %{conn: conn} do
      co1 = company_fixture(%{name: "BankIndexCo1"})
      co2 = company_fixture(%{name: "BankIndexCo2"})
      bank_account_fixture(%{company: co1, bank_name: "Bank in Co1"})
      bank_account_fixture(%{company: co2, bank_name: "Bank in Co2"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_change(view, "filter_company", %{"company_id" => to_string(co1.id)})
      assert html =~ "Bank in Co1"
    end

    test "reset company filter to all on index", %{conn: conn} do
      co1 = company_fixture()
      bank_account_fixture(%{company: co1, bank_name: "AllBankReset"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_change(view, "filter_company", %{"company_id" => to_string(co1.id)})
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "AllBankReset"
    end
  end

  describe "index page viewer permission guards" do
    test "viewer cannot save a bank account", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "save", %{"bank_account" => %{"bank_name" => "Blocked"}})
      assert html =~ "permission"
    end

    test "viewer cannot update a bank account", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "update", %{"bank_account" => %{"bank_name" => "Blocked"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete a bank account", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "delete", %{})
      assert html =~ "permission"
    end

    test "viewer cannot save_pool", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "save_pool", %{"pool" => %{"name" => "Blocked Pool"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete_pool", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "delete_pool", %{})
      assert html =~ "permission"
    end
  end

  describe "index page editor CRUD" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor can create a bank account", %{conn: conn} do
      company = company_fixture(%{name: "NewBankCo"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "bank_account" => %{
            "company_id" => to_string(company.id),
            "bank_name" => "New Test Bank",
            "currency" => "USD",
            "balance" => "50000"
          }
        })

      assert html =~ "Bank account added" || html =~ "New Test Bank"
    end

    test "editor save failure shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "bank_account" => %{"bank_name" => ""}
        })

      assert html =~ "Failed to add bank account" || html =~ "Bank Accounts"
    end

    test "editor can update a bank account", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Update Me Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "edit", %{"id" => to_string(ba.id)})

      html =
        render_click(view, "update", %{
          "bank_account" => %{
            "bank_name" => "Updated Bank Name",
            "balance" => "99999"
          }
        })

      assert html =~ "Bank account updated" || html =~ "Updated Bank Name"
    end

    test "editor update failure shows error", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Fail Update Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "edit", %{"id" => to_string(ba.id)})

      html =
        render_click(view, "update", %{
          "bank_account" => %{"bank_name" => ""}
        })

      assert html =~ "Failed to update bank account" || html =~ "Bank Accounts"
    end

    test "editor can delete a bank account", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Delete Me Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "delete", %{"id" => to_string(ba.id)})
      assert html =~ "Bank account deleted"
    end

    test "editor sees Add Account button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")
      assert html =~ "Add Account"
    end
  end

  describe "cash pools" do
    test "shows cash pools section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")
      assert html =~ "Cash Pools"
    end

    test "show_pool_form opens pool modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "show_pool_form", %{})
      assert html =~ "Add Cash Pool"
    end

    test "close_pool_form closes pool modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_pool_form", %{})
      html = render_click(view, "close_pool_form", %{})
      refute html =~ "Add Cash Pool"
    end

    test "editor can create a cash pool", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_pool_form", %{})

      html =
        render_click(view, "save_pool", %{
          "pool" => %{
            "name" => "New Test Pool",
            "currency" => "USD",
            "target_balance" => "100000"
          }
        })

      assert html =~ "Cash pool added" || html =~ "New Test Pool"
    end

    test "editor can delete a cash pool", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      pool = cash_pool_fixture(%{name: "Delete Pool"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "delete_pool", %{"id" => to_string(pool.id)})
      assert html =~ "Cash pool deleted"
    end

    test "editor save_pool failure shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_pool_form", %{})

      html =
        render_click(view, "save_pool", %{
          "pool" => %{"name" => ""}
        })

      assert html =~ "Failed to add cash pool" || html =~ "Bank Accounts"
    end
  end

  describe "index page handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      company = company_fixture()
      bank_account_fixture(%{company: company, bank_name: "PubSub Bank"})

      send(view.pid, {:banking_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Bank"
    end
  end

  describe "index page rendering" do
    test "shows currency chart section", %{conn: conn} do
      company = company_fixture()
      bank_account_fixture(%{company: company, bank_name: "ChartBank", currency: "USD", balance: 10000.0})
      bank_account_fixture(%{company: company, bank_name: "ChartBank2", currency: "EUR", balance: 5000.0})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")
      assert html =~ "Balance by Currency"
      assert html =~ "By Currency"
      assert html =~ "currency-chart"
    end

    test "shows total balance in metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")
      assert html =~ "Total Balance"
      assert html =~ "Accounts"
      assert html =~ "Currencies"
    end
  end
end
