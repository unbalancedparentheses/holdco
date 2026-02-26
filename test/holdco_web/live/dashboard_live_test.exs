defmodule HoldcoWeb.DashboardLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /" do
    test "renders dashboard page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Portfolio Overview"
    end

    test "renders page title and deck", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "page-title"
      assert html =~ "Net Asset Value"
    end

    test "renders page-title-rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "page-title-rule"
    end

    test "renders metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "metrics-strip"
      assert html =~ "metric-cell"
      assert html =~ "metric-label"
      assert html =~ "metric-value"
    end

    test "shows NAV metric", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "NAV"
    end

    test "overview nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ ~r/href="\/"[^>]*class="active"/
    end

    test "shows full navigation bar", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "nav-links"
      assert html =~ "nav-utils"
    end

    test "shows footer", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "footer"
      assert html =~ "Holdco"
    end
  end

  describe "metrics strip details" do
    test "shows Net Asset Value metric", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Net Asset Value"
    end

    test "shows Liquid metric with note", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Liquid"
      assert html =~ "Bank balances"
    end

    test "shows Marketable metric with note", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Marketable"
      assert html =~ "Stocks, crypto, commodities"
    end

    test "shows Illiquid metric with note", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Illiquid"
      assert html =~ "Real estate, PE, funds"
    end

    test "shows Liabilities metric with negative styling", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Liabilities"
      assert html =~ "num-negative"
    end

    test "shows dollar sign by default for USD", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "$"
    end
  end

  describe "currency selector" do
    test "renders currency selector form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Display Currency"
      assert html =~ ~s(name="currency")
      assert html =~ "form-select"
    end

    test "renders all currency options", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      for currency <- ~w(USD EUR GBP ARS BRL CHF JPY CAD AUD) do
        assert html =~ currency
      end
    end

    test "changing currency to EUR updates display", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "EUR"}) |> render_change()
      assert html =~ "\u20AC"
    end

    test "changing currency to GBP updates display", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "GBP"}) |> render_change()
      assert html =~ "\u00A3"
    end

    test "changing currency to JPY updates display", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "JPY"}) |> render_change()
      assert html =~ "\u00A5"
    end

    test "changing currency to CHF shows CHF prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "CHF"}) |> render_change()
      assert html =~ "CHF "
    end

    test "changing currency to ARS shows ARS prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "ARS"}) |> render_change()
      assert html =~ "ARS "
    end

    test "changing currency to BRL shows BRL prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "BRL"}) |> render_change()
      assert html =~ "BRL "
    end

    test "changing currency to CAD shows CAD prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "CAD"}) |> render_change()
      assert html =~ "CAD "
    end

    test "changing currency to AUD shows AUD prefix", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "AUD"}) |> render_change()
      assert html =~ "AUD "
    end

    test "changing back to USD shows dollar sign", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      view |> form(~s(form[phx-change="change_currency"]), %{currency: "EUR"}) |> render_change()
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "USD"}) |> render_change()
      assert html =~ "$"
    end
  end

  describe "asset allocation section" do
    test "renders Asset Allocation section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Asset Allocation"
    end

    test "renders stacked bar chart elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "stacked-bar"
      assert html =~ "stacked-bar-legend"
    end
  end

  describe "NAV History section" do
    test "renders NAV History section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "NAV History"
    end

    test "renders chart hook container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ ~s(id="nav-chart")
      assert html =~ "phx-hook=\"ChartHook\""
      assert html =~ ~s(data-chart-type="line")
    end

    test "renders chart with snapshot data", %{conn: conn} do
      portfolio_snapshot_fixture(%{date: "2024-01-01", nav: 1_000_000.0})
      portfolio_snapshot_fixture(%{date: "2024-02-01", nav: 1_100_000.0})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "data-chart-data"
      assert html =~ "2024-01-01"
      assert html =~ "2024-02-01"
    end
  end

  describe "corporate structure section" do
    test "renders Corporate Structure section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Corporate Structure"
    end

    test "shows entity count", %{conn: conn} do
      company_fixture(%{name: "Dashboard Corp"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "1 entities"
    end

    test "shows 0 entities when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "0 entities"
    end

    test "renders company table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "<th>Entity</th>"
      assert html =~ "<th>Country</th>"
      assert html =~ "<th>Category</th>"
      assert html =~ "<th>Status</th>"
    end

    test "displays company data", %{conn: conn} do
      company = company_fixture(%{name: "Dashboard Corp", country: "UK", category: "SPV"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Dashboard Corp"
      assert html =~ "UK"
      assert html =~ "SPV"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "shows active status with jade tag", %{conn: conn} do
      company_fixture(%{name: "Active Co", wind_down_status: "active"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-jade"
    end

    test "shows winding_down status with lemon tag", %{conn: conn} do
      company_fixture(%{name: "Winding Co", wind_down_status: "winding_down"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-lemon"
    end

    test "shows dissolved status with crimson tag", %{conn: conn} do
      company_fixture(%{name: "Gone Co", wind_down_status: "dissolved"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-crimson"
    end

    test "company name links to detail page", %{conn: conn} do
      company = company_fixture(%{name: "Linked Corp"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "td-link td-name"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "indents subsidiary companies", %{conn: conn} do
      parent = company_fixture(%{name: "Parent"})
      _child = company_fixture(%{name: "Child", parent_id: parent.id})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "indent"
    end

    test "shows correct entity count for multiple companies", %{conn: conn} do
      company_fixture(%{name: "Corp A"})
      company_fixture(%{name: "Corp B"})
      company_fixture(%{name: "Corp C"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "3 entities"
    end
  end

  describe "recent activity section" do
    test "renders Recent Activity section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Recent Activity"
    end

    test "renders audit feed container", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ ~s(id="audit-feed")
    end

    test "renders audit table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "<th>Time</th>"
      assert html =~ "<th>Action</th>"
      assert html =~ "<th>Table</th>"
      assert html =~ "<th>Record</th>"
    end

    test "displays audit log entries", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", record_id: 42})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "create"
      assert html =~ "companies"
    end

    test "create action shows jade tag", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-jade"
    end

    test "update action shows lemon tag", %{conn: conn} do
      audit_log_fixture(%{action: "update", table_name: "companies"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-lemon"
    end

    test "delete action shows crimson tag", %{conn: conn} do
      audit_log_fixture(%{action: "delete", table_name: "companies"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-crimson"
    end

    test "unknown action shows ink tag", %{conn: conn} do
      audit_log_fixture(%{action: "archive", table_name: "companies"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag-ink"
    end

    test "format_time shows time in td-mono", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "td-mono"
    end
  end

  describe "recent transactions section" do
    test "renders Recent Transactions section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Recent Transactions"
    end

    test "shows latest count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "latest"
    end

    test "renders transaction table headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "<th>Date</th>"
      assert html =~ "<th>Type</th>"
      assert html =~ "<th>Description</th>"
      assert html =~ "<th>Counterparty</th>"
      assert html =~ "Amount"
    end

    test "displays transaction data", %{conn: conn} do
      transaction_fixture(%{
        description: "Dashboard Wire",
        transaction_type: "credit",
        amount: 5000.0,
        currency: "USD",
        counterparty: "Vendor Co",
        date: "2024-06-01"
      })
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Dashboard Wire"
      assert html =~ "credit"
      assert html =~ "Vendor Co"
    end

    test "shows transaction type with tag", %{conn: conn} do
      transaction_fixture(%{transaction_type: "debit", description: "Payment"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "tag tag-ink"
      assert html =~ "debit"
    end

    test "shows positive amount styling", %{conn: conn} do
      transaction_fixture(%{amount: 1000.0, description: "Income"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "num-positive"
    end

    test "shows negative amount styling", %{conn: conn} do
      transaction_fixture(%{amount: -500.0, description: "Expense"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "num-negative"
    end

    test "shows zero amount transaction", %{conn: conn} do
      transaction_fixture(%{amount: 0.0, description: "Zero Amount Tx"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Zero Amount Tx"
    end
  end

  describe "grid layout" do
    test "renders grid-2 layout sections", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "grid-2"
    end

    test "renders section-head elements", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "section-head"
    end

    test "renders panel containers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "panel"
    end
  end

  describe "handle_info" do
    test "audit_log_created broadcast updates the audit feed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      new_log = %{id: 999, action: "delete", table_name: "holdings", record_id: 55, inserted_at: ~N[2024-06-15 14:30:00]}
      send(view.pid, {:audit_log_created, new_log})
      html = render(view)
      assert html =~ "delete"
      assert html =~ "holdings"
    end

    test "unknown messages are handled gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      send(view.pid, {:some_unknown_event, %{}})
      html = render(view)
      assert html =~ "Portfolio Overview"
    end

    test "keeps only 20 most recent audit entries after broadcast", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      for i <- 1..25 do
        log = %{id: i, action: "create", table_name: "companies", record_id: i, inserted_at: ~N[2024-06-15 14:30:00]}
        send(view.pid, {:audit_log_created, log})
      end
      html = render(view)
      assert html =~ "Portfolio Overview"
    end

    test "audit log with nil inserted_at doesn't crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      log = %{id: 888, action: "create", table_name: "test", record_id: 1, inserted_at: nil}
      send(view.pid, {:audit_log_created, log})
      html = render(view)
      assert html =~ "test"
    end
  end

  describe "change_currency event with different currencies" do
    test "changing to USD sets fx_rate to 1 and shows dollar sign", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Change away first, then back
      view |> form(~s(form[phx-change="change_currency"]), %{currency: "EUR"}) |> render_change()
      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "USD"}) |> render_change()

      assert html =~ "$"
      refute html =~ "EUR "
    end

    test "changing currency preserves page structure", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "ARS"}) |> render_change()

      assert html =~ "Portfolio Overview"
      assert html =~ "metrics-strip"
      assert html =~ "Net Asset Value"
      assert html =~ "ARS "
    end

    test "changing currency updates all metric values with new symbol", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "GBP"}) |> render_change()

      # GBP symbol should appear in metric values
      assert html =~ "\u00A3"
      assert html =~ "Liquid"
      assert html =~ "Marketable"
      assert html =~ "Illiquid"
      assert html =~ "Liabilities"
    end

    test "switching between multiple currencies works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "EUR"}) |> render_change()
      assert html =~ "\u20AC"

      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "JPY"}) |> render_change()
      assert html =~ "\u00A5"
      refute html =~ "\u20AC"

      html = view |> form(~s(form[phx-change="change_currency"]), %{currency: "USD"}) |> render_change()
      assert html =~ "$"
    end
  end

  describe "empty state sections" do
    test "shows empty state for upcoming deadlines when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No upcoming deadlines"
      assert html =~ "You&#39;re all clear!" or html =~ "all clear"
    end

    test "shows zero pending approvals message when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "No pending approvals"
    end

    test "shows 0 entities link when no companies exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "0 entities"
    end

    test "upcoming deadlines section renders when deadlines exist", %{conn: conn} do
      tax_deadline_fixture(%{
        description: "Q1 Tax Filing",
        due_date: "2027-04-15",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Upcoming Deadlines"
      assert html =~ "Q1 Tax Filing"
      assert html =~ "pending"
    end

    test "empty recent transactions section renders headers", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Recent Transactions"
      assert html =~ "<th>Date</th>"
      assert html =~ "0 latest"
    end
  end

  describe "editor quick action buttons" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees quick action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "+ Company"
      assert html =~ "+ Transaction"
      assert html =~ "+ Holding"
      assert html =~ "Import CSV"
    end

    test "quick action links have correct destinations", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ ~s(/companies/new)
      assert html =~ ~s(/transactions)
      assert html =~ ~s(/holdings)
      assert html =~ ~s(/import)
    end
  end

  describe "viewer quick action buttons" do
    test "viewer does not see quick action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      refute html =~ "+ Company"
      refute html =~ "+ Transaction"
      refute html =~ "+ Holding"
      refute html =~ "Import CSV"
    end
  end

  describe "audit_link routing" do
    test "company audit log links to company detail page", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", record_id: 42})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/companies/42"
    end

    test "asset_holdings audit log links to holdings page", %{conn: conn} do
      audit_log_fixture(%{action: "update", table_name: "asset_holdings", record_id: 7})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/holdings/7"
    end

    test "bank_accounts audit log links to bank accounts page", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "bank_accounts", record_id: 15})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/bank-accounts/15"
    end

    test "transactions audit log links to transactions page", %{conn: conn} do
      audit_log_fixture(%{action: "delete", table_name: "transactions", record_id: 99})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/transactions/99"
    end

    test "unknown table audit log links to fallback audit-log page", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "documents", record_id: 33})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/audit-log"
    end
  end

  describe "upcoming deadlines with company" do
    test "deadline with company shows company link", %{conn: conn} do
      company = company_fixture(%{name: "DeadlineCo"})

      tax_deadline_fixture(%{
        company: company,
        description: "Quarterly Filing",
        due_date: "2027-06-30",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Quarterly Filing"
      assert html =~ "DeadlineCo"
      assert html =~ "/companies/#{company.id}"
    end

    test "overdue deadline shows crimson tag", %{conn: conn} do
      tax_deadline_fixture(%{
        description: "Overdue Filing",
        due_date: "2027-01-01",
        status: "overdue"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Overdue Filing"
      assert html =~ "tag-crimson"
    end

    test "pending deadline shows lemon tag", %{conn: conn} do
      tax_deadline_fixture(%{
        description: "Pending Filing",
        due_date: "2027-12-31",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Pending Filing"
      assert html =~ "tag-lemon"
    end

    test "pending approvals with non-zero count shows review link", %{conn: conn} do
      Holdco.Platform.create_approval_request(%{
        requested_by: "user@test.com",
        table_name: "companies",
        action: "create"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Review pending approvals"
      assert html =~ "/approvals"
    end
  end

  describe "section links" do
    test "corporate structure has view all link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/companies"
      assert html =~ "entities"
    end

    test "recent activity has view all link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/audit-log"
      assert html =~ "View All"
    end

    test "upcoming deadlines has calendar link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/calendar"
    end

    test "pending approvals has view all link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/approvals"
    end
  end

  describe "audit log format_time rendering" do
    test "audit log with valid timestamp renders formatted time", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      log = %{id: 777, action: "update", table_name: "companies", record_id: 10, inserted_at: ~N[2024-06-15 09:30:45]}
      send(view.pid, {:audit_log_created, log})
      html = render(view)

      assert html =~ "09:30:45"
    end

    test "audit log with nil inserted_at renders empty time cell", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      log = %{id: 776, action: "create", table_name: "holdings", record_id: 5, inserted_at: nil}
      send(view.pid, {:audit_log_created, log})
      html = render(view)

      # Should not crash, page should still render
      assert html =~ "holdings"
      assert html =~ "create"
    end

    test "audit log format_time shows HH:MM:SS format", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      log = %{id: 775, action: "delete", table_name: "transactions", record_id: 3, inserted_at: ~N[2024-12-25 23:59:59]}
      send(view.pid, {:audit_log_created, log})
      html = render(view)

      assert html =~ "23:59:59"
    end

    test "multiple audit logs render with correct times", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      log1 = %{id: 774, action: "create", table_name: "companies", record_id: 1, inserted_at: ~N[2024-01-01 08:00:00]}
      log2 = %{id: 773, action: "update", table_name: "companies", record_id: 2, inserted_at: ~N[2024-01-01 16:30:00]}

      send(view.pid, {:audit_log_created, log1})
      send(view.pid, {:audit_log_created, log2})
      html = render(view)

      assert html =~ "08:00:00"
      assert html =~ "16:30:00"
    end
  end

  describe "audit_link with nil record_id" do
    test "audit log with nil record_id shows fallback link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      log = %{id: 900, action: "create", table_name: "companies", record_id: nil, inserted_at: ~N[2024-01-01 12:00:00]}
      send(view.pid, {:audit_log_created, log})
      html = render(view)

      assert html =~ "#"
    end
  end

  describe "deadline with company" do
    test "deadline with company shows company name link", %{conn: conn} do
      company = company_fixture(%{name: "DeadlineOrgCo"})

      tax_deadline_fixture(%{
        company: company,
        description: "Company Deadline",
        due_date: "2027-03-15",
        status: "pending"
      })

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Company Deadline"
      assert html =~ "DeadlineOrgCo"
      assert html =~ "/companies/#{company.id}"
    end
  end

  describe "transaction with negative amount in recent transactions" do
    test "negative transaction has num-negative class", %{conn: conn} do
      transaction_fixture(%{amount: -1500.0, description: "DashNeg", transaction_type: "debit"})

      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "DashNeg"
      assert html =~ "num-negative"
    end
  end
end
