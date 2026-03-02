defmodule HoldcoWeb.AccountingChartTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders existing accounts", %{conn: conn} do
      company = company_fixture(%{name: "AcctCo"})
      account_fixture(%{company_id: company.id, code: "1100", name: "Checking", account_type: "asset", currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/accounts/chart")

      assert html =~ "1100"
      assert html =~ "Checking"
      assert html =~ "asset"
      assert html =~ "USD"
    end

    test "editor sees Add Account button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/accounts/chart")

      assert html =~ "Add Account"
    end
  end

  # ── Filter Company ──────────────────────────────────────

  describe "filter_company event" do
    test "filters accounts by company", %{conn: conn} do
      c1 = company_fixture(%{name: "CompanyA"})
      c2 = company_fixture(%{name: "CompanyB"})
      account_fixture(%{company_id: c1.id, code: "1010", name: "CashA", account_type: "asset"})
      account_fixture(%{company_id: c2.id, code: "1020", name: "CashB", account_type: "asset"})

      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(c1.id)})
        |> render_change()

      assert html =~ "CashA"
      refute html =~ "CashB"
    end

    test "empty company_id shows all accounts", %{conn: conn} do
      company = company_fixture()
      account_fixture(%{company_id: company.id, code: "1030", name: "All Cash", account_type: "asset"})

      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "All Cash"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens Add Account modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      html = view |> element("button", "Add Account") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Account"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="account[code]")
      assert html =~ ~s(name="account[name]")
      assert html =~ ~s(name="account[account_type]")
      assert html =~ ~s(name="account[parent_id]")
      assert html =~ ~s(name="account[currency]")
      assert html =~ ~s(name="account[company_id]")
    end

    test "form shows account type options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      html = view |> element("button", "Add Account") |> render_click()

      assert html =~ "Asset"
      assert html =~ "Liability"
      assert html =~ "Equity"
      assert html =~ "Revenue"
      assert html =~ "Expense"
    end

    test "close_form closes the modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      view |> element("button", "Add Account") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  # ── Save Account ────────────────────────────────────────

  describe "save event" do
    test "creates an account and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SaveAcctCo"})

      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      view |> element("button", "Add Account") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "account" => %{
            "company_id" => company.id,
            "code" => "3000",
            "name" => "Retained Earnings",
            "account_type" => "equity",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Account created"
      assert html =~ "3000"
      assert html =~ "Retained Earnings"
      refute html =~ "dialog-overlay"
    end

    test "creates an account without company_id", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")
      view |> element("button", "Add Account") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "account" => %{
            "company_id" => "",
            "code" => "4000",
            "name" => "Sales Revenue",
            "account_type" => "revenue"
          }
        })
        |> render_submit()

      assert html =~ "Account created"
      assert html =~ "Sales Revenue"
    end

  end

  # ── Delete Account ──────────────────────────────────────

  describe "delete event" do
    test "deletes an account and shows flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      acct = account_fixture(%{company_id: company.id, code: "5001", name: "Office Supplies", account_type: "expense"})

      {:ok, view, html} = live(conn, ~p"/accounts/chart")
      assert html =~ "Office Supplies"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{acct.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Account deleted"
      refute html =~ "Office Supplies"
    end

  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/accounts/chart")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Chart of Accounts"
    end
  end
end
