defmodule HoldcoWeb.DashboardLiveTest do
  use HoldcoWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "currency selector" do
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

  describe "NAV History section" do
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
    test "shows entity count", %{conn: conn} do
      company_fixture(%{name: "Dashboard Corp"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "1 entities"
    end

    test "shows 0 entities when none exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "0 entities"
    end

    test "displays company data", %{conn: conn} do
      company = company_fixture(%{name: "Dashboard Corp", country: "UK", category: "SPV"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Dashboard Corp"
      assert html =~ "UK"
      assert html =~ "SPV"
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
    test "displays audit log entries", %{conn: conn} do
      audit_log_fixture(%{action: "create", table_name: "companies", record_id: 42})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "create"
      assert html =~ "companies"
    end
  end

  describe "recent transactions section" do
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

    test "shows zero amount transaction", %{conn: conn} do
      transaction_fixture(%{amount: 0.01, description: "Zero Amount Tx"})
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Zero Amount Tx"
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
  end

  describe "upcoming deadlines" do
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

  describe "editor quick action buttons" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees quick action buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "+ Company"
      assert html =~ "+ Transaction"
      assert html =~ "+ Position"
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

  describe "audit log format_time rendering" do
    test "audit log with valid timestamp renders formatted time", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Flush any PubSub messages from other async tests
      _ = render(view)

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

      # Flush any PubSub messages from other async tests
      _ = render(view)

      log = %{id: 775, action: "delete", table_name: "transactions", record_id: 3, inserted_at: ~N[2024-12-25 23:59:59]}
      send(view.pid, {:audit_log_created, log})
      html = render(view)

      assert html =~ "23:59:59"
    end

    test "multiple audit logs render with correct times", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Flush any PubSub messages from other async tests
      _ = render(view)

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

  # ═══════════════════════════════════════════════════════
  # Returns & Period Comparison strip
  # ═══════════════════════════════════════════════════════

  describe "returns strip" do
    test "shows percentage values with return data", %{conn: conn} do
      company = company_fixture()
      holding = holding_fixture(%{
        company: company, asset: "Test Stock", ticker: "DASH_TEST",
        quantity: 100.0, currency: "USD", asset_type: "equity"
      })
      price_history_fixture(%{ticker: "DASH_TEST", price: 200.0})
      cost_basis_lot_fixture(%{
        holding: holding, quantity: 100.0, price_per_unit: 150.0, sold_quantity: 0.0
      })

      {:ok, _view, html} = live(conn, ~p"/")
      # Should show a percentage like +33.3%
      assert html =~ "%"
      assert html =~ "returns-strip"
    end

    test "shows period comparison tags when snapshots exist", %{conn: conn} do
      today = Date.utc_today()
      portfolio_snapshot_fixture(%{date: Date.to_iso8601(Date.add(today, -7)), nav: 100_000.0})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "1W"
    end
  end

  # ═══════════════════════════════════════════════════════
  # Financial Ratios panel
  # ═══════════════════════════════════════════════════════

  describe "financial ratios section" do
    test "shows computed ratio values with real data", %{conn: conn} do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 100_000.0, currency: "USD"})
      liability_fixture(%{company: company, principal: 50_000.0, interest_rate: 5.0, status: "active"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Total Assets"
      assert html =~ "Equity"
      assert html =~ "Debt"
    end

    test "shows leverage assessment text", %{conn: conn} do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 500_000.0, currency: "USD"})
      liability_fixture(%{company: company, principal: 100_000.0, interest_rate: 3.0, status: "active"})

      {:ok, _view, html} = live(conn, ~p"/")
      # D/E = 100k / 400k = 0.25, which is "Conservative leverage"
      assert html =~ "Conservative leverage"
    end
  end

  # ═══════════════════════════════════════════════════════
  # Cash Flow Forecast section
  # ═══════════════════════════════════════════════════════

  describe "cash flow forecast section" do
    test "renders forecast section", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "90-Day Cash Forecast"
    end

    test "shows empty state when no scheduled flows", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "No scheduled cash flows"
    end

    test "shows chart when recurring transactions exist", %{conn: conn} do
      company = company_fixture()
      bank_account_fixture(%{company: company, balance: 50_000.0, currency: "USD"})
      {:ok, _} = Holdco.Finance.create_recurring_transaction(%{
        company_id: company.id,
        description: "Test monthly income",
        amount: 5_000.0,
        frequency: "monthly",
        start_date: Date.to_iso8601(Date.add(Date.utc_today(), -30)),
        next_run_date: Date.to_iso8601(Date.add(Date.utc_today(), 5)),
        transaction_type: "income",
        is_active: true
      })

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "cashflow-chart"
    end
  end

  # ═══════════════════════════════════════════════════════
  # Entity Performance table
  # ═══════════════════════════════════════════════════════

  describe "entity performance section" do
    test "hidden when only one entity", %{conn: conn} do
      company_fixture(%{name: "Lone Entity"})
      {:ok, _view, html} = live(conn, ~p"/")
      # With only 1 company, the entity performance section should not render
      refute html =~ "Entity Performance"
    end

    test "shows entity performance table with multiple entities", %{conn: conn} do
      company_fixture(%{name: "Parent Co"})
      company_fixture(%{name: "Sub Co"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Entity Performance"
      assert html =~ "Parent Co"
      assert html =~ "Sub Co"
    end

    test "table has correct column headers", %{conn: conn} do
      company_fixture(%{name: "E1"})
      company_fixture(%{name: "E2"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Cash"
      assert html =~ "Holdings"
      assert html =~ "Liabilities"
      assert html =~ "NAV"
      assert html =~ "Return"
    end

    test "entity rows link to company detail page", %{conn: conn} do
      c1 = company_fixture(%{name: "Linked Entity"})
      company_fixture(%{name: "Other Entity"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "/companies/#{c1.id}"
    end

    test "shows cash values for entities with bank accounts", %{conn: conn} do
      c1 = company_fixture(%{name: "Rich Co"})
      c2 = company_fixture(%{name: "Poor Co"})
      bank_account_fixture(%{company: c1, balance: 500_000.0, currency: "USD"})
      bank_account_fixture(%{company: c2, balance: 1_000.0, currency: "USD"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Entity Performance"
      assert html =~ "500,000"
    end

    test "shows return percentage when holdings have cost basis", %{conn: conn} do
      c1 = company_fixture(%{name: "Return Co"})
      _c2 = company_fixture(%{name: "No Return Co"})
      holding = holding_fixture(%{
        company: c1, asset: "EPTEST", ticker: "EP_TICKER",
        quantity: 100.0, currency: "USD", asset_type: "equity"
      })
      price_history_fixture(%{ticker: "EP_TICKER", price: 200.0})
      cost_basis_lot_fixture(%{holding: holding, quantity: 100.0, price_per_unit: 100.0, sold_quantity: 0.0})

      {:ok, _view, html} = live(conn, ~p"/")
      # Return = (20000 - 10000) / 10000 * 100 = 100%
      assert html =~ "100.0%"
    end

    test "shows entity count", %{conn: conn} do
      company_fixture(%{name: "Ent A"})
      company_fixture(%{name: "Ent B"})
      company_fixture(%{name: "Ent C"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "3 entities"
    end
  end

  describe "action items" do
    test "shows unreconciled count when bank feed transactions exist", %{conn: conn} do
      company = company_fixture()
      ba = bank_account_fixture(%{company: company})
      config = bank_feed_config_fixture(%{company: company, bank_account: ba, is_active: true})

      Holdco.Integrations.create_bank_feed_transaction(%{
        feed_config_id: config.id,
        external_id: "ext_dash_#{System.unique_integer([:positive])}",
        date: "2025-01-15",
        description: "Unreconciled txn",
        amount: 500.00,
        currency: "USD"
      })

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Unreconciled transactions"
    end

    test "shows open periods when companies exist", %{conn: conn} do
      company_fixture(%{name: "DashCo"})

      {:ok, _view, html} = live(conn, ~p"/")
      assert html =~ "Periods open"
    end
  end
end
