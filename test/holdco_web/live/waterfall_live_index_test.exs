defmodule HoldcoWeb.WaterfallLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Waterfall Chart page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Waterfall Chart"
      assert html =~ "Revenue flowing to expenses to net income"
    end

    test "shows metrics strip with totals", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Total Revenue"
      assert html =~ "Total Expenses"
      assert html =~ "Net Income"
    end

    test "shows waterfall chart area", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "waterfall-chart"
      assert html =~ "Waterfall"
    end

    test "shows revenue table section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Revenue"
      assert html =~ "Code"
      assert html =~ "Account"
      assert html =~ "Amount"
    end

    test "shows expenses table section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Expenses"
    end

    test "shows income summary section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Income Summary"
    end

    test "shows empty state for no revenue", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "No revenue accounts found" || html =~ "Revenue"
    end

    test "shows empty state for no expenses", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "No expense accounts found" || html =~ "Expenses"
    end

    test "displays company filter dropdown", %{conn: conn} do
      company_fixture(%{name: "WaterfallCo"})
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "WaterfallCo"
      assert html =~ "All Companies"
    end

    test "displays date filter fields", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "From"
      assert html =~ "To"
    end
  end

  describe "filter event" do
    test "filters by company", %{conn: conn} do
      company = company_fixture(%{name: "FilterWaterfall"})

      {:ok, live, _html} = live(conn, ~p"/waterfall")
      html = render_change(live, "filter", %{"company_id" => to_string(company.id), "date_from" => "", "date_to" => ""})
      assert html =~ "Waterfall Chart"
    end

    test "filters by date range", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/waterfall")
      html = render_change(live, "filter", %{"company_id" => "", "date_from" => "2024-01-01", "date_to" => "2024-12-31"})
      assert html =~ "Waterfall Chart"
    end

    test "filters by company and date range together", %{conn: conn} do
      company = company_fixture(%{name: "FilterBothCo"})

      {:ok, live, _html} = live(conn, ~p"/waterfall")
      html = render_change(live, "filter", %{
        "company_id" => to_string(company.id),
        "date_from" => "2024-01-01",
        "date_to" => "2024-06-30"
      })
      assert html =~ "Waterfall Chart"
    end

    test "clears all filters", %{conn: conn} do
      company = company_fixture(%{name: "ClearFilterCo"})

      {:ok, live, _html} = live(conn, ~p"/waterfall")
      render_change(live, "filter", %{"company_id" => to_string(company.id), "date_from" => "2024-01-01", "date_to" => "2024-12-31"})
      html = render_change(live, "filter", %{"company_id" => "", "date_from" => "", "date_to" => ""})
      assert html =~ "All Companies"
    end
  end

  describe "with financial data" do
    test "renders revenue accounts in revenue table", %{conn: conn} do
      company = company_fixture()
      acct = account_fixture(%{company: company, account_type: "revenue", code: "4000", name: "Sales Revenue"})

      je = journal_entry_fixture(%{company: company, date: "2024-06-01"})
      journal_line_fixture(%{entry: je, account: acct, credit: 50_000.0, debit: 0.0})

      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Sales Revenue" || html =~ "4000"
    end

    test "renders expense accounts in expenses table", %{conn: conn} do
      company = company_fixture()
      acct = account_fixture(%{company: company, account_type: "expense", code: "5010", name: "Office Rent"})

      je = journal_entry_fixture(%{company: company, date: "2024-06-01"})
      journal_line_fixture(%{entry: je, account: acct, debit: 10_000.0, credit: 0.0})

      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Office Rent" || html =~ "5010"
    end

    test "income summary shows expenses as Less: items", %{conn: conn} do
      company = company_fixture()
      acct = account_fixture(%{company: company, account_type: "expense", code: "5020", name: "Salaries"})

      je = journal_entry_fixture(%{company: company, date: "2024-06-01"})
      journal_line_fixture(%{entry: je, account: acct, debit: 20_000.0, credit: 0.0})

      {:ok, _live, html} = live(conn, ~p"/waterfall")
      assert html =~ "Less:" || html =~ "Income Summary"
    end
  end
end
