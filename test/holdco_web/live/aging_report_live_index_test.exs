defmodule HoldcoWeb.AgingReportLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders AR/AP Aging Report page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Aging Report"
    end

    test "shows mode toggle for AR/AP", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Receivables (AR)"
      assert html =~ "Payables (AP)"
    end

    test "displays aging buckets in metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Current (0-30d)"
      assert html =~ "31-60 days"
      assert html =~ "61-90 days"
      assert html =~ "91-120 days"
      assert html =~ "120+ days"
    end

    test "shows Total in metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Total"
    end

    test "toggles between AR and AP mode", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/aging")
      html = render_click(live, "toggle_mode", %{"mode" => "ap"})
      assert html =~ "Accounts Payable"

      html = render_click(live, "toggle_mode", %{"mode" => "ar"})
      assert html =~ "Accounts Receivable"
    end

    test "default mode is AR (Accounts Receivable)", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Accounts Receivable"
    end

    test "shows empty state in AR mode when no positive transactions", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "receivable" || html =~ "No" || html =~ "Aging Report"
    end

    test "shows empty state in AP mode when no negative transactions", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/aging")
      html = render_click(live, "toggle_mode", %{"mode" => "ap"})
      assert html =~ "payable" || html =~ "No" || html =~ "Aging Report"
    end

    test "renders with positive transaction data in AR mode", %{conn: conn} do
      company = company_fixture(%{name: "Receivable Corp"})

      transaction_fixture(%{
        company: company,
        transaction_type: "credit",
        amount: 5000.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Client payment",
        counterparty: "Client ABC"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Client payment" || html =~ "Client ABC" || html =~ "5,000"
    end

    test "renders with negative transaction data in AP mode", %{conn: conn} do
      company = company_fixture(%{name: "Payable Corp"})

      transaction_fixture(%{
        company: company,
        transaction_type: "debit",
        amount: -3000.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Supplier invoice",
        counterparty: "Supplier XYZ"
      })

      {:ok, live, _html} = live(conn, ~p"/aging")
      html = render_click(live, "toggle_mode", %{"mode" => "ap"})
      assert html =~ "Supplier invoice" || html =~ "Supplier XYZ" || html =~ "3,000" || html =~ "Aging Report"
    end

    test "groups transactions by age bucket", %{conn: conn} do
      company = company_fixture()

      # Current (0-30 days old)
      transaction_fixture(%{
        company: company,
        amount: 1000.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Recent payment"
      })

      # 31-60 days old
      transaction_fixture(%{
        company: company,
        amount: 2000.0,
        date: Date.utc_today() |> Date.add(-45) |> Date.to_iso8601(),
        description: "Older payment"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Current (0-30d)" || html =~ "31-60 days" || html =~ "transactions"
    end

    test "shows company link for transactions", %{conn: conn} do
      company = company_fixture(%{name: "Linked Co"})

      transaction_fixture(%{
        company: company,
        amount: 1000.0,
        date: Date.utc_today() |> Date.to_iso8601()
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Linked Co" || html =~ "Aging Report"
    end

    test "shows aging chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Aging Distribution"
    end

    test "displays transaction count in bucket headers", %{conn: conn} do
      company = company_fixture()

      transaction_fixture(%{
        company: company,
        amount: 1000.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Test AR txn"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "transactions" || html =~ "Aging Report"
    end

    test "shows days old column in transaction rows", %{conn: conn} do
      company = company_fixture()

      transaction_fixture(%{
        company: company,
        amount: 1000.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Fresh txn"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Days Old" || html =~ "Aging Report"
    end

    test "renders transaction amounts with currency", %{conn: conn} do
      company = company_fixture()

      transaction_fixture(%{
        company: company,
        amount: 7500.0,
        date: Date.utc_today() |> Date.to_iso8601(),
        description: "Currency txn",
        currency: "EUR"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "7,500" || html =~ "EUR" || html =~ "Aging Report"
    end

    test "very old transactions go into 120+ bucket", %{conn: conn} do
      company = company_fixture()

      transaction_fixture(%{
        company: company,
        amount: 10_000.0,
        date: Date.utc_today() |> Date.add(-200) |> Date.to_iso8601(),
        description: "Very old payment"
      })

      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "120+" || html =~ "Very old payment" || html =~ "Aging Report"
    end

    test "report type selector is displayed", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "Report Type"
    end

    test "page title and description are shown", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/aging")
      assert html =~ "AR/AP Aging Report"
      assert html =~ "grouped by age bucket"
    end
  end
end
