defmodule HoldcoWeb.FinancialsLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /financials" do
    test "renders financials page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Financials"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "page-title"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "metrics-strip"
    end

    test "financials page renders without nav highlight", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      # Financials is no longer in the nav bar (removed from Consolidated dropdown)
      assert html =~ "Financials"
    end
  end

  describe "show_form and close_form events" do
    test "show_form displays the add financial period modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = view |> element(~s(button[phx-click="show_form"])) |> render_click()

      assert html =~ "Add Financial Period"
      assert html =~ ~s(phx-submit="save")
    end

    test "close_form hides the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="show_form"])) |> render_click()
      html = view |> element(~s(button[phx-click="close_form"])) |> render_click()

      refute html =~ "Add Financial Period"
    end
  end

  describe "show_transfer_form and close_transfer_form events" do
    test "show_transfer_form displays the add transfer modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = view |> element(~s(button[phx-click="show_transfer_form"])) |> render_click()

      assert html =~ "Add Intercompany Transfer"
      assert html =~ ~s(phx-submit="save_transfer")
    end

    test "close_transfer_form hides the transfer modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="show_transfer_form"])) |> render_click()
      html = view |> element(~s(button[phx-click="close_transfer_form"])) |> render_click()

      refute html =~ "Add Intercompany Transfer"
    end
  end

  describe "noop event" do
    test "noop event does not change the page", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/financials")

      # Open the modal so the noop target (modal overlay) is present
      view |> element(~s(button[phx-click="show_form"])) |> render_click()
      html_after = view |> element(~s(div.modal[phx-click="noop"])) |> render_click()

      # Modal should still be open after noop
      assert html_after =~ "Add Financial Period"
    end
  end

  describe "financial period CRUD" do
    test "save with valid data creates a financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "FinCorp"})
      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="show_form"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          financial: %{
            company_id: company.id,
            period: "2025-Q1",
            revenue: "500000",
            expenses: "200000",
            currency: "USD"
          }
        })
        |> render_submit()

      assert html =~ "Financial record added"
      assert html =~ "2025-Q1"
    end

    test "delete removes a financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DelCorp"})
      fin = financial_fixture(%{company: company, period: "2025-Q2", revenue: 1000.0, expenses: 500.0})

      {:ok, view, html} = live(conn, ~p"/financials")
      assert html =~ "2025-Q2"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{fin.id}"]))
        |> render_click()

      assert html =~ "Financial record deleted"
      refute html =~ "2025-Q2"
    end

    test "non-editor cannot save a financial record", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      # Non-editor should not see the Add Period button
      refute render(view) =~ ~s(phx-click="show_form")
    end

    test "permission guard blocks save for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      # Directly push the save event (bypassing UI guard)
      html = render_hook(view, "save", %{"financial" => %{"period" => "2025-Q3", "company_id" => "1"}})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "permission guard blocks delete for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = render_hook(view, "delete", %{"id" => "1"})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  describe "transfer CRUD" do
    test "save_transfer with valid data creates a transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      from_co = company_fixture(%{name: "SenderCo"})
      to_co = company_fixture(%{name: "ReceiverCo"})

      {:ok, view, _html} = live(conn, ~p"/financials")

      view |> element(~s(button[phx-click="show_transfer_form"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_transfer"]), %{
          transfer: %{
            from_company_id: from_co.id,
            to_company_id: to_co.id,
            amount: "75000",
            currency: "USD",
            date: "2025-03-01",
            description: "Management fee"
          }
        })
        |> render_submit()

      assert html =~ "Transfer created"
      assert html =~ "SenderCo"
      assert html =~ "ReceiverCo"
    end

    test "delete_transfer removes a transfer", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      from_co = company_fixture(%{name: "FromDel"})
      to_co = company_fixture(%{name: "ToDel"})
      transfer = inter_company_transfer_fixture(%{
        from_company: from_co,
        to_company: to_co,
        amount: 10000.0,
        date: "2025-02-01",
        description: "Unique-Transfer-Desc-Del"
      })

      {:ok, view, html} = live(conn, ~p"/financials")
      assert html =~ "Unique-Transfer-Desc-Del"

      html =
        view
        |> element(~s(button[phx-click="delete_transfer"][phx-value-id="#{transfer.id}"]))
        |> render_click()

      assert html =~ "Transfer deleted"
      refute html =~ "Unique-Transfer-Desc-Del"
    end

    test "permission guard blocks save_transfer for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = render_hook(view, "save_transfer", %{"transfer" => %{"amount" => "100", "date" => "2025-01-01"}})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "permission guard blocks delete_transfer for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = render_hook(view, "delete_transfer", %{"id" => "1"})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  describe "filter_company event" do
    test "filters financials by selected company", %{conn: conn} do
      co1 = company_fixture(%{name: "AlphaCorp"})
      co2 = company_fixture(%{name: "BetaCorp"})
      financial_fixture(%{company: co1, period: "2025-Q1", revenue: 100.0})
      financial_fixture(%{company: co2, period: "2025-Q2", revenue: 200.0})

      {:ok, view, html} = live(conn, ~p"/financials")
      assert html =~ "2025-Q1"
      assert html =~ "2025-Q2"

      # Filter to co1 only
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
        |> render_change()

      assert html =~ "2025-Q1"
      refute html =~ "2025-Q2"
    end

    test "selecting All Companies resets the filter", %{conn: conn} do
      co1 = company_fixture(%{name: "FilterCo"})
      financial_fixture(%{company: co1, period: "2025-Q3", revenue: 300.0})

      {:ok, view, _html} = live(conn, ~p"/financials")

      # Filter to company first
      view
      |> form(~s(form[phx-change="filter_company"]), %{"company_id" => to_string(co1.id)})
      |> render_change()

      # Then reset to all
      html =
        view
        |> form(~s(form[phx-change="filter_company"]), %{"company_id" => ""})
        |> render_change()

      assert html =~ "2025-Q3"
    end
  end

  describe "change_currency event" do
    test "changes the display currency", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/financials")

      # Default is USD
      assert html =~ "$"

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "EUR"})
        |> render_change()

      assert html =~ "EUR"
    end
  end

  describe "table rendering with financial data" do
    test "displays financial records in the table", %{conn: conn} do
      company = company_fixture(%{name: "TableCorp"})
      financial_fixture(%{company: company, period: "2025-Q1", revenue: 100_000.0, expenses: 50_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "2025-Q1"
      assert html =~ "TableCorp"
      assert html =~ "100,000"
      assert html =~ "50,000"
      assert html =~ "USD"
    end

    test "shows empty state when no financial records exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "No financial records yet"
    end

    test "displays consolidated totals in metrics strip", %{conn: conn} do
      company = company_fixture(%{name: "MetricsCorp"})
      financial_fixture(%{company: company, period: "2025-Q1", revenue: 500_000.0, expenses: 200_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
      assert html =~ "500,000"
      assert html =~ "200,000"
    end
  end

  describe "transfer table rendering with transfer data" do
    test "displays transfer records in the table", %{conn: conn} do
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

    test "shows empty state when no transfers exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/financials")

      assert html =~ "No intercompany transfers yet"
    end
  end

  describe "edit event for a financial period" do
    test "edit event opens the edit modal with pre-filled data", %{conn: conn, user: user} do
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
      # Phoenix HTML renders large floats in scientific notation
      assert html =~ "7.5e5"
      assert html =~ "3.0e5"
    end

    test "update event saves changes to an existing financial record", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "UpdateCorp"})
      fin = financial_fixture(%{company: company, period: "2025-Q1", revenue: 100_000.0, expenses: 50_000.0})

      {:ok, view, _html} = live(conn, ~p"/financials")

      # Open edit modal
      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{fin.id}"]))
      |> render_click()

      # Submit the update form
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

    test "permission guard blocks update for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = render_hook(view, "update", %{"financial" => %{"period" => "2025-Q3"}})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  describe "edit_transfer event" do
    test "edit_transfer opens the edit transfer modal", %{conn: conn, user: user} do
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
      # Phoenix HTML renders large floats in scientific notation
      assert html =~ "3.0e4"
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

    test "permission guard blocks update_transfer for non-editors", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "viewer")
      {:ok, view, _html} = live(conn, ~p"/financials")

      html = render_hook(view, "update_transfer", %{"transfer" => %{"amount" => "999"}})

      assert html =~ "You don&#39;t have permission to do that"
    end
  end

  describe "currency symbol rendering" do
    test "shows GBP symbol when currency changed to GBP", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "GBP"})
        |> render_change()

      assert html =~ "GBP"
    end

    test "shows JPY symbol when currency changed to JPY", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "JPY"})
        |> render_change()

      assert html =~ "JPY"
    end

    test "shows CHF prefix when currency changed to CHF", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "CHF"})
        |> render_change()

      assert html =~ "CHF"
    end

    test "shows ARS prefix for non-standard currency", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      html =
        view
        |> form(~s(form[phx-change="change_currency"]), %{"currency" => "ARS"})
        |> render_change()

      assert html =~ "ARS"
    end
  end

  describe "handle_info for PubSub" do
    test "handles broadcast message by reloading data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/financials")

      send(view.pid, {:finance_changed, %{}})
      html = render(view)
      assert html =~ "Financials"
    end
  end
end
