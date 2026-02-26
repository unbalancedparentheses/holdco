defmodule HoldcoWeb.BankAccountsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "mount and render" do
    test "renders the page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "<h1>Bank Accounts</h1>"
      assert html =~ "accounts across all entities"
      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders metrics strip with total balance, accounts count, and currencies", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "metrics-strip"
      assert html =~ "Total Balance"
      assert html =~ "Accounts"
      assert html =~ "Currencies"
    end

    test "renders All Accounts table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "<th>Bank</th>"
      assert html =~ "Account #"
      assert html =~ "<th>IBAN</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Currency</th>"
      assert html =~ "Balance"
      assert html =~ "<th>Company</th>"
    end

    test "renders section headings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "All Accounts"
      assert html =~ "Balance by Currency"
      assert html =~ "By Currency"
      assert html =~ "Cash Pools"
    end

    test "renders empty state when no accounts exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "No bank accounts yet."
      assert html =~ "empty-state"
    end

    test "renders empty state for cash pools when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "No cash pools yet."
    end

    test "renders company filter dropdown", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "All Companies"
      assert html =~ "form-select"
      assert html =~ ~s(name="company_id")
    end

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

    test "renders the currency chart hook container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ ~s(id="currency-chart")
      assert html =~ "ChartHook"
    end

    test "renders cash pool table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "<th>Name</th>"
      assert html =~ "Target Balance"
      assert html =~ "# Entries"
    end

    test "shows cash pool data when pools exist", %{conn: conn} do
      cash_pool_fixture(%{name: "Main Pool", currency: "EUR", target_balance: 100_000.0})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Main Pool"
      assert html =~ "EUR"
      assert html =~ "100,000"
    end
  end

  describe "viewer role (no can_write)" do
    test "does not show Add Account button for viewer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      refute html =~ "Add Account"
    end

    test "does not show Add Pool button for viewer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      refute html =~ "Add Pool"
    end

    test "does not show delete buttons for viewer", %{conn: conn} do
      bank_account_fixture()
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      refute html =~ "btn btn-danger btn-sm"
    end
  end

  describe "editor role" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "shows Add Account button for editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Add Account"
      assert html =~ ~s(phx-click="show_form")
    end

    test "shows Add Pool button for editor", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "Add Pool"
      assert html =~ ~s(phx-click="show_pool_form")
    end

    test "shows delete button on accounts for editor", %{conn: conn} do
      bank_account_fixture()
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "btn btn-danger btn-sm"
      assert html =~ "Del"
      assert html =~ ~s(phx-click="delete")
    end

    test "shows delete button on cash pools for editor", %{conn: conn} do
      cash_pool_fixture()
      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ ~s(phx-click="delete_pool")
    end

    test "clicking Add Account opens the bank account modal form", %{conn: conn} do
      company_fixture(%{name: "ModalCo"})
      {:ok, view, _html} = live(conn, ~p"/bank-accounts")

      html = view |> element("button", "Add Account") |> render_click()

      assert html =~ "modal-overlay"
      assert html =~ "modal-header"
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

      assert html =~ "modal-overlay"
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
      refute html =~ "modal-overlay"
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
      refute html =~ "modal-overlay"
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

    test "company options appear in the filter dropdown", %{conn: conn} do
      company_fixture(%{name: "DropdownBankCo"})

      {:ok, _view, html} = live(conn, ~p"/bank-accounts")

      assert html =~ "DropdownBankCo"
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
end
