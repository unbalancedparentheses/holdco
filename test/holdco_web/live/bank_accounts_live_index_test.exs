defmodule HoldcoWeb.BankAccountsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "shows bank account data when accounts exist", %{conn: conn} do
      company = company_fixture(%{name: "BankTestCo"})

      bank_account_fixture(%{
        company: company,
        bank_name: "First National",
        account_number: "123456",
        iban: "DE89370400440532013000",
        account_type: "operating",
        currency: "USD",
        balance: 50_000.0
      })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "BankTestCo"
      assert html =~ "First National"
      assert html =~ "123456"
      assert html =~ "DE89370400440532013000"
      assert html =~ "operating"
      assert html =~ "USD"
      assert html =~ "50,000"
      assert html =~ "1 accounts across all entities"
    end

    test "shows cash pool data when pools exist", %{conn: conn} do
      cash_pool_fixture(%{name: "Main Pool", currency: "EUR", target_balance: 100_000.0})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Main Pool"
      assert html =~ "EUR"
      assert html =~ "100,000"
    end
  end

  describe "editor role" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "clicking Add Account opens the bank account modal form", %{conn: conn} do
      company_fixture(%{name: "ModalCo"})
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      html = view |> element("button", "Add Account") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "dialog-header"
      assert html =~ "Add Bank Account"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="bank_account[company_id]")
      assert html =~ ~s(name="bank_account[bank_name]")
      assert html =~ ~s(name="bank_account[account_number]")
      assert html =~ ~s(name="bank_account[iban]")
      assert html =~ ~s(name="bank_account[swift]")
      assert html =~ ~s(name="bank_account[currency]")
      assert html =~ ~s(name="bank_account[account_type]")
      assert html =~ ~s(name="bank_account[balance]")
      assert html =~ "ModalCo"
    end

    test "bank account form shows account type options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      html = view |> element("button", "Add Account") |> render_click()

      assert html =~ "Operating"
      assert html =~ "Savings"
      assert html =~ "Escrow"
      assert html =~ "Trust"
    end

    test "clicking Cancel closes the bank account modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      view |> element("button", "Add Account") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "Add Bank Account"
    end

    test "clicking Add Pool opens the cash pool modal form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      html = view |> element("button", "Add Pool") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Cash Pool"
      assert html =~ ~s(phx-submit="save_pool")
      assert html =~ ~s(name="pool[name]")
      assert html =~ ~s(name="pool[currency]")
      assert html =~ ~s(name="pool[target_balance]")
      assert html =~ ~s(name="pool[notes]")
    end

    test "clicking Cancel closes the cash pool modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      view |> element("button", "Add Pool") |> render_click()

      # The close_pool_form Cancel button
      html = view |> element(~s(button[phx-click="close_pool_form"])) |> render_click()

      refute html =~ "Add Cash Pool"
    end

    test "submitting the bank account form creates an account", %{conn: conn} do
      company = company_fixture(%{name: "SaveBankCo"})
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      view |> element("button", "Add Account") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save\"]", %{
          "bank_account" => %{
            "company_id" => to_string(company.id),
            "bank_name" => "Chase Bank",
            "account_number" => "9876543",
            "currency" => "USD",
            "account_type" => "operating",
            "balance" => "25000"
          }
        })
        |> render_submit()

      assert html =~ "Bank account added"
      refute html =~ "dialog-overlay"
    end

    test "submitting the cash pool form creates a pool", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      view |> element("button", "Add Pool") |> render_click()

      html =
        view
        |> form("form[phx-submit=\"save_pool\"]", %{
          "pool" => %{
            "name" => "Treasury Pool",
            "currency" => "USD",
            "target_balance" => "500000",
            "notes" => "Main treasury"
          }
        })
        |> render_submit()

      assert html =~ "Cash pool added"
      refute html =~ "dialog-overlay"
    end

    test "deleting a bank account removes it from the list", %{conn: conn} do
      ba = bank_account_fixture(%{bank_name: "DeleteMeBank"})
      {:ok, view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "DeleteMeBank"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{ba.id}"]))
        |> render_click()

      assert html =~ "Bank account deleted"
      refute html =~ "DeleteMeBank"
    end

    test "deleting a cash pool removes it from the list", %{conn: conn} do
      pool = cash_pool_fixture(%{name: "DeleteMePool"})
      {:ok, view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "DeleteMePool"

      html =
        view
        |> element(~s(button[phx-click="delete_pool"][phx-value-id="#{pool.id}"]))
        |> render_click()

      assert html =~ "Cash pool deleted"
      refute html =~ "DeleteMePool"
    end
  end

  describe "company filter" do
    test "filtering by company shows only that company's accounts", %{conn: conn} do
      co1 = company_fixture(%{name: "FilterBankCo1"})
      co2 = company_fixture(%{name: "FilterBankCo2"})
      bank_account_fixture(%{company: co1, bank_name: "Bank Alpha"})
      bank_account_fixture(%{company: co2, bank_name: "Bank Beta"})

      {:ok, view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Bank Alpha"
      assert html =~ "Bank Beta"

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "Bank Alpha"
      refute html =~ "Bank Beta"
    end

    test "resetting filter shows all accounts", %{conn: conn} do
      co1 = company_fixture(%{name: "ResetCo1"})
      co2 = company_fixture(%{name: "ResetCo2"})
      bank_account_fixture(%{company: co1, bank_name: "Bank One"})
      bank_account_fixture(%{company: co2, bank_name: "Bank Two"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      view
      |> form("form[phx-change=\"filter_company\"]", %{"company_id" => to_string(co1.id)})
      |> render_change()

      html =
        view
        |> form("form[phx-change=\"filter_company\"]", %{"company_id" => ""})
        |> render_change()

      assert html =~ "Bank One"
      assert html =~ "Bank Two"
    end

  end

  describe "by currency table" do
    test "shows currency breakdown when accounts with different currencies exist", %{conn: conn} do
      company = company_fixture()
      bank_account_fixture(%{company: company, currency: "USD", balance: 10_000.0})
      bank_account_fixture(%{company: company, currency: "EUR", balance: 5_000.0})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "USD"
      assert html =~ "EUR"
    end
  end

  # ------------------------------------------------------------------
  # Show page (/bank-accounts/:id)
  # ------------------------------------------------------------------

  describe "show page" do
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
    end

    test "shows company link when company exists", %{conn: conn} do
      company = company_fixture(%{name: "LinkedBankCompany"})
      account = bank_account_fixture(%{company: company, bank_name: "Company Bank"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "LinkedBankCompany"
      assert html =~ ~s(/companies/#{company.id})
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
    end

    test "shows debit transaction with negative styling", %{conn: conn} do
      company = company_fixture(%{name: "NegTxnCo"})
      account = bank_account_fixture(%{company: company, bank_name: "NegTxnBank", currency: "USD"})

      transaction_fixture(%{
        company: company,
        transaction_type: "debit",
        description: "Outgoing payment",
        amount: 5000.0,
        currency: "USD",
        date: "2024-04-01"
      })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Outgoing payment"
      assert html =~ "debit"
    end

    test "shows Import Statement button", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "ImportTestBank"})
      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "Import Statement"
    end

    test "clicking Import Statement opens upload dialog", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "ImportDialogBank"})
      {:ok, view, _html} = live(conn, ~p"/bank-accounts/#{account.id}")

      html = view |> element("button", "Import Statement") |> render_click()

      assert html =~ "Import Bank Statement"
      assert html =~ "dialog-overlay"
      assert html =~ "Parse Statement"
    end

    test "closing import dialog returns to idle", %{conn: conn} do
      account = bank_account_fixture(%{bank_name: "CloseDialogBank"})
      {:ok, view, _html} = live(conn, ~p"/bank-accounts/#{account.id}")

      view |> element("button", "Import Statement") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "handles account with nil balance", %{conn: conn} do
      account =
        bank_account_fixture(%{
          bank_name: "Nil Balance Bank",
          balance: nil,
          account_type: "checking"
        })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{account.id}")

      assert html =~ "$0"
    end

  end

  # ------------------------------------------------------------------
  # Editor: edit + validation errors
  # ------------------------------------------------------------------

  describe "editor edit and validation" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "edit opens edit form", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Edit Me Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      html = render_click(view, "edit", %{"id" => to_string(ba.id)})
      assert html =~ "Edit Bank Account"
      assert html =~ "Save Changes"
    end

    test "save failure shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_form", %{})

      html =
        render_click(view, "save", %{
          "bank_account" => %{"bank_name" => ""}
        })

      assert html =~ "Failed to add bank account"
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

      assert html =~ "Bank account updated"
    end

    test "update failure shows error", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "Fail Update Bank"})

      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "edit", %{"id" => to_string(ba.id)})

      html =
        render_click(view, "update", %{
          "bank_account" => %{"bank_name" => ""}
        })

      assert html =~ "Failed to update bank account"
    end

    test "save_pool failure shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")
      render_click(view, "show_pool_form", %{})

      html =
        render_click(view, "save_pool", %{
          "pool" => %{"name" => ""}
        })

      assert html =~ "Failed to add cash pool"
    end
  end

  # ------------------------------------------------------------------
  # PubSub
  # ------------------------------------------------------------------

  describe "pubsub" do
    test "banking_changed message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      company = company_fixture()
      bank_account_fixture(%{company: company, bank_name: "PubSub Bank"})

      send(view.pid, {:banking_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Bank"
    end
  end

  describe "stored statements" do
    test "shows imported statements section when documents exist", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company, bank_name: "StatementBank"})

      {:ok, doc} =
        Holdco.Documents.create_document(%{
          name: "Bank Statement - StatementBank - 2025-01-15",
          doc_type: "bank_statement",
          company_id: company.id
        })

      Holdco.Documents.create_document_upload(%{
        document_id: doc.id,
        file_path: "/tmp/test.csv",
        file_name: "january-2025.csv",
        file_size: 1234,
        content_type: "text/csv"
      })

      {:ok, _view, html} = live(conn, ~p"/bank-accounts/#{ba.id}")
      assert html =~ "Imported Statements"
      assert html =~ "january-2025.csv"
    end
  end
end
