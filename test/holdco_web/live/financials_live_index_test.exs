defmodule HoldcoWeb.FinancialsLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "<h1>Financials</h1>"
      assert html =~ "P&amp;L across all companies and periods"
      assert html =~ "page-title-rule"
    end

    test "renders metrics strip with totals", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "metrics-strip"
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
      assert html =~ "Total Liabilities"
    end

    test "renders currency filter with USD default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "consolidated in USD"
      assert html =~ ~s(name="currency")
    end

    test "renders company filter", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "All Companies"
      assert html =~ ~s(name="company_id")
    end

    test "renders empty state when no financials", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "No financial records yet."
    end

    test "renders financial data in table", %{conn: conn} do
      company = company_fixture(%{name: "FinCo"})
      financial_fixture(%{company_id: company.id, period: "2025-Q1", revenue: 100_000.0, expenses: 50_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "2025-Q1"
      assert html =~ "FinCo"
    end

    test "renders intercompany transfers section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Intercompany Transfers"
      assert html =~ "No intercompany transfers yet."
    end

    test "viewer cannot see Add Period button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      refute html =~ "Add Period"
    end

    test "editor sees Add Period button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Add Period"
    end

    test "editor sees Add Transfer button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Add Transfer"
    end
  end

  # ── Show/Close Form ─────────────────────────────────────

  describe "show_form and close_form events" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "show_form opens Add Financial Period modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = view |> element("button", "Add Period") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Financial Period"
      assert html =~ ~s(phx-submit="save")
      assert html =~ ~s(name="financial[period]")
    end

    test "close_form closes the modal via Cancel button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element("button", "Add Period") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"]), "Cancel") |> render_click()

      refute html =~ "Add Financial Period"
    end

    test "show_transfer_form opens transfer modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = view |> element("button", "Add Transfer") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Intercompany Transfer"
      assert html =~ ~s(phx-submit="save_transfer")
    end

    test "close_transfer_form closes transfer modal", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element("button", "Add Transfer") |> render_click()
      html = view |> element(~s(button[phx-click="close_transfer_form"]), "Cancel") |> render_click()

      refute html =~ "Add Intercompany Transfer"
    end
  end

  # ── Filter Company ──────────────────────────────────────

  describe "filter_company event" do
    test "filters financials by company", %{conn: conn} do
      c1 = company_fixture(%{name: "AlphaCo"})
      c2 = company_fixture(%{name: "BetaCo"})
      financial_fixture(%{company_id: c1.id, period: "2025-Q1", revenue: 1000.0})
      financial_fixture(%{company_id: c2.id, period: "2025-Q2", revenue: 2000.0})

      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(c1.id)})
        |> render_change()

      assert html =~ "2025-Q1"
      refute html =~ "2025-Q2"
    end

    test "empty company_id shows all companies", %{conn: conn} do
      c1 = company_fixture(%{name: "AlphaCo"})
      financial_fixture(%{company_id: c1.id, period: "2025-Q1"})

      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "2025-Q1"
    end
  end

  # ── Change Currency ─────────────────────────────────────

  describe "change_currency event" do
    test "changes display currency", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "EUR"})
        |> render_change()

      assert html =~ "consolidated in EUR"
    end
  end

  # ── Save Financial ──────────────────────────────────────

  describe "save event" do
    test "creates a financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "SaveCo"})

      {:ok, view, _html} = live(conn, ~p"/financials")
      view |> element("button", "Add Period") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "financial" => %{
            "company_id" => company.id,
            "period" => "2025-Q3",
            "revenue" => "75000",
            "expenses" => "25000",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Financial record added"
      assert html =~ "2025-Q3"
      refute html =~ "dialog-overlay"
    end

    test "viewer cannot save a financial record", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      render_hook(view, "save", %{"financial" => %{"period" => "2025-Q1"}})

      assert render(view) =~ "permission"
    end
  end

  # ── Delete Financial ────────────────────────────────────

  describe "delete event" do
    test "deletes a financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DelCo"})
      f = financial_fixture(%{company_id: company.id, period: "2025-Q4"})

      {:ok, view, html} = live(conn, ~p"/financials")
      assert html =~ "2025-Q4"

      view |> element(~s(button[phx-click="delete"][phx-value-id="#{f.id}"])) |> render_click()

      html = render(view)
      assert html =~ "Financial record deleted"
      refute html =~ "2025-Q4"
    end

    test "viewer cannot delete a financial record", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      render_hook(view, "delete", %{"id" => "1"})
      assert render(view) =~ "permission"
    end
  end

  # ── Save/Delete Transfer ────────────────────────────────

  describe "save_transfer event" do
    test "creates an intercompany transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      c1 = company_fixture(%{name: "FromCo"})
      c2 = company_fixture(%{name: "ToCo"})

      {:ok, view, _html} = live(conn, ~p"/financials")
      view |> element("button", "Add Transfer") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_transfer"]), %{
          "transfer" => %{
            "from_company_id" => c1.id,
            "to_company_id" => c2.id,
            "amount" => "10000",
            "currency" => "USD",
            "date" => "2025-03-01"
          }
        })
        |> render_submit()

      assert html =~ "Transfer created"
      refute html =~ "dialog-overlay"
    end

    test "viewer cannot save a transfer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      render_hook(view, "save_transfer", %{"transfer" => %{"amount" => "1000"}})
      assert render(view) =~ "permission"
    end
  end

  describe "delete_transfer event" do
    test "deletes an intercompany transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ict = inter_company_transfer_fixture()

      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="delete_transfer"][phx-value-id="#{ict.id}"])) |> render_click()

      assert render(view) =~ "Transfer deleted"
    end

    test "viewer cannot delete a transfer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      render_hook(view, "delete_transfer", %{"id" => "1"})
      assert render(view) =~ "permission"
    end
  end

  # ── Noop event ──────────────────────────────────────────

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      render_hook(view, "noop", %{})
      assert render(view) =~ "Financials"
    end
  end
end
