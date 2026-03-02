defmodule HoldcoWeb.FinancialsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ── Mount & Render ──────────────────────────────────────

  describe "mount and render" do
    test "renders financial data in table", %{conn: conn} do
      company = company_fixture(%{name: "FinCo"})
      financial_fixture(%{company_id: company.id, period: "2025-Q1", revenue: 100_000.0, expenses: 50_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "2025-Q1"
      assert html =~ "FinCo"
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

  end

  describe "delete_transfer event" do
    test "deletes an intercompany transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      ict = inter_company_transfer_fixture()

      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="delete_transfer"][phx-value-id="#{ict.id}"])) |> render_click()

      assert render(view) =~ "Transfer deleted"
    end

  end

  # ── Edit Financial ─────────────────────────────────────

  describe "edit event" do
    test "opens the edit modal with pre-filled data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "EditCorp"})
      fin = financial_fixture(%{company: company, period: "2025-Q4", revenue: 750_000.0, expenses: 300_000.0, currency: "EUR"})

      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{fin.id}"]))
        |> render_click()

      assert html =~ "Edit Financial Period"
      assert html =~ ~s(phx-submit="update")
      assert html =~ "2025-Q4"
    end

    test "update saves changes to an existing financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "UpdateCorp"})
      fin = financial_fixture(%{company: company, period: "2025-Q1", revenue: 100_000.0, expenses: 50_000.0})

      {:ok, view, _html} = live(conn, ~p"/financials")

      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{fin.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          financial: %{
            company_id: company.id,
            period: "2025-Q1-Updated",
            revenue: "999000",
            expenses: "111000",
            currency: "USD"
          }
        })
        |> render_submit()

      assert html =~ "Financial record updated"
      assert html =~ "2025-Q1-Updated"
    end
  end

  # ── Edit Transfer ────────────────────────────────────

  describe "edit_transfer event" do
    test "opens the edit transfer modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      from_co = company_fixture(%{name: "EditFrom"})
      to_co = company_fixture(%{name: "EditTo"})
      transfer = inter_company_transfer_fixture(%{
        from_company: from_co,
        to_company: to_co,
        amount: 30_000.0,
        date: "2025-04-01",
        description: "Quarterly payment"
      })

      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> element(~s(button[phx-click="edit_transfer"][phx-value-id="#{transfer.id}"]))
        |> render_click()

      assert html =~ "Edit Intercompany Transfer"
      assert html =~ ~s(phx-submit="update_transfer")
      assert html =~ "2025-04-01"
    end

    test "update_transfer saves changes to an existing transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      from_co = company_fixture(%{name: "UpdFrom"})
      to_co = company_fixture(%{name: "UpdTo"})
      transfer = inter_company_transfer_fixture(%{
        from_company: from_co,
        to_company: to_co,
        amount: 20_000.0,
        date: "2025-05-01"
      })

      {:ok, view, _html} = live(conn, ~p"/financials")

      view
      |> element(~s(button[phx-click="edit_transfer"][phx-value-id="#{transfer.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update_transfer"]), %{
          transfer: %{
            from_company_id: from_co.id,
            to_company_id: to_co.id,
            amount: "55000",
            currency: "EUR",
            date: "2025-05-15",
            description: "Updated payment"
          }
        })
        |> render_submit()

      assert html =~ "Transfer updated"
    end
  end

  # ── Data Display with Formatting ─────────────────────

  describe "data display with formatting" do
    test "displays consolidated totals in metrics strip", %{conn: conn} do
      company = company_fixture(%{name: "MetricsCorp"})
      financial_fixture(%{company: company, period: "2025-Q1", revenue: 500_000.0, expenses: 200_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "500,000"
      assert html =~ "200,000"
    end

    test "displays transfer records with formatted data", %{conn: conn} do
      from_co = company_fixture(%{name: "TransferFrom"})
      to_co = company_fixture(%{name: "TransferTo"})
      inter_company_transfer_fixture(%{
        from_company: from_co,
        to_company: to_co,
        amount: 25_000.0,
        currency: "USD",
        date: "2025-06-15",
        description: "Licensing fee"
      })

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "TransferFrom"
      assert html =~ "TransferTo"
      assert html =~ "25,000"
      assert html =~ "2025-06-15"
      assert html =~ "Licensing fee"
    end
  end

  # ── PubSub ───────────────────────────────────────────

  describe "PubSub handle_info" do
    test "handles finance_changed broadcast by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      send(view.pid, {:finance_changed, %{}})
      html = render(view)
      assert html =~ "Financials"
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
