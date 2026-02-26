defmodule HoldcoWeb.CashForecastLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Cash Flow Forecast page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Cash Flow Forecast"
      assert html =~ "12-month cash flow projection"
    end

    test "shows metrics strip with all labels", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Current Cash Position"
      assert html =~ "Projected End of Quarter"
      assert html =~ "Projected End of Year"
      assert html =~ "Monthly Net Cash Flow"
    end

    test "shows projected cash flow chart area", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "cash-forecast-chart"
      assert html =~ "Projected Cash Flow"
    end

    test "shows monthly projections table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Monthly Projections"
      assert html =~ "Month"
      assert html =~ "Inflows"
      assert html =~ "Outflows"
      assert html =~ "One-Time"
      assert html =~ "Net"
      assert html =~ "Ending Balance"
    end

    test "shows recurring income section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Recurring Income"
      assert html =~ "Total Monthly Inflow"
    end

    test "shows recurring expenses section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Recurring Expenses"
      assert html =~ "Total Monthly Outflow"
    end

    test "shows known one-time expenses section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Known One-Time Expenses"
    end

    test "shows empty state for recurring income when no patterns detected", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "No recurring income patterns detected"
    end

    test "shows empty state for recurring expenses when no patterns detected", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "No recurring expense patterns detected"
    end

    test "shows empty state for one-time expenses when none upcoming", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "No upcoming one-time expenses"
    end
  end

  describe "with bank account data" do
    test "current cash position reflects bank account balances", %{conn: conn} do
      company = company_fixture(%{name: "CashCo"})
      bank_account_fixture(%{company: company, bank_name: "Chase", balance: 500_000.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Current Cash Position"
      # Balance should show 500,000
      assert html =~ "500,000"
    end

    test "multiple bank accounts sum into current cash", %{conn: conn} do
      company = company_fixture(%{name: "MultiBankCo"})
      bank_account_fixture(%{company: company, bank_name: "Bank A", balance: 100_000.0, currency: "USD"})
      bank_account_fixture(%{company: company, bank_name: "Bank B", balance: 200_000.0, currency: "USD"})

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "300,000"
    end
  end

  describe "recurring transaction detection" do
    test "detects recurring income from 3+ similar transactions", %{conn: conn} do
      company = company_fixture()
      # Create 3 credit transactions with the same description
      transaction_fixture(%{company: company, description: "Monthly Rent Income", amount: 5000.0, transaction_type: "credit", date: "2024-01-15"})
      transaction_fixture(%{company: company, description: "Monthly Rent Income", amount: 5000.0, transaction_type: "credit", date: "2024-02-15"})
      transaction_fixture(%{company: company, description: "Monthly Rent Income", amount: 5000.0, transaction_type: "credit", date: "2024-03-15"})

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Monthly Rent Income"
    end

    test "detects recurring expenses from 3+ similar transactions", %{conn: conn} do
      company = company_fixture()
      # Create 3 debit transactions with same description but negative amounts
      transaction_fixture(%{company: company, description: "Office Lease", amount: -3000.0, transaction_type: "debit", date: "2024-01-15"})
      transaction_fixture(%{company: company, description: "Office Lease", amount: -3000.0, transaction_type: "debit", date: "2024-02-15"})
      transaction_fixture(%{company: company, description: "Office Lease", amount: -3000.0, transaction_type: "debit", date: "2024-03-15"})

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Office Lease"
    end

    test "does not detect recurring for fewer than 3 transactions", %{conn: conn} do
      company = company_fixture()
      transaction_fixture(%{company: company, description: "Rare Payment", amount: 1000.0, date: "2024-01-15"})
      transaction_fixture(%{company: company, description: "Rare Payment", amount: 1000.0, date: "2024-02-15"})

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      refute html =~ "Rare Payment"
    end
  end

  describe "one-time expenses" do
    test "shows upcoming liability maturities", %{conn: conn} do
      company = company_fixture()
      today = Date.utc_today()
      future_date = today |> Date.add(60) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        liability_type: "loan",
        creditor: "Big Bank",
        principal: 50_000.0,
        status: "active",
        maturity_date: future_date,
        currency: "USD"
      })

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Big Bank"
      assert html =~ "Liability"
    end

    test "shows upcoming tax deadlines", %{conn: conn} do
      company = company_fixture()
      today = Date.utc_today()
      future_date = today |> Date.add(30) |> Date.to_iso8601()

      tax_deadline_fixture(%{
        company: company,
        description: "Quarterly Filing",
        jurisdiction: "US",
        due_date: future_date,
        status: "pending",
        estimated_amount: 10_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      assert html =~ "Quarterly Filing"
      assert html =~ "Tax"
    end

    test "does not show past liability maturities", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{
        company: company,
        liability_type: "loan",
        creditor: "Past Bank",
        principal: 25_000.0,
        status: "active",
        maturity_date: "2020-01-01",
        currency: "USD"
      })

      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      refute html =~ "Past Bank"
    end
  end

  describe "monthly projections" do
    test "renders 12 months of projections", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/cash-forecast")
      # Should have 12 rows of monthly projections
      today = Date.utc_today()
      label = "#{today.year}-#{String.pad_leading(Integer.to_string(today.month), 2, "0")}"
      assert html =~ label
    end
  end

  describe "noop event" do
    test "noop does not change the page", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/cash-forecast")
      html = render_click(live, "noop", %{})
      assert html =~ "Cash Flow Forecast"
    end
  end
end
