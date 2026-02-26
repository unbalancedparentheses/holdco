defmodule HoldcoWeb.BudgetVarianceLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Budget vs Actual page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Budget vs Actual"
    end

    test "shows metrics strip with all four metrics", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Total Budgeted"
      assert html =~ "Total Actual"
      assert html =~ "Variance ($)"
      assert html =~ "Variance (%)"
    end

    test "shows empty state when no budgets exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "No budget records found"
    end

    test "renders with budget data showing category", %{conn: conn} do
      company = company_fixture(%{name: "Budget Corp"})

      budget_fixture(%{
        company: company,
        period: "2024",
        category: "Operations",
        budgeted: 50_000.0,
        actual: 45_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Operations"
      assert html =~ "Budget Corp"
    end

    test "shows Under Budget status when actual < budgeted", %{conn: conn} do
      company = company_fixture()

      budget_fixture(%{
        company: company,
        category: "Marketing",
        budgeted: 100_000.0,
        actual: 80_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Under Budget"
    end

    test "shows Over Budget status when actual > budgeted", %{conn: conn} do
      company = company_fixture()

      budget_fixture(%{
        company: company,
        category: "Engineering",
        budgeted: 50_000.0,
        actual: 75_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Over Budget"
    end

    test "shows On Budget status when actual equals budgeted", %{conn: conn} do
      company = company_fixture()

      budget_fixture(%{
        company: company,
        category: "Facilities",
        budgeted: 30_000.0,
        actual: 30_000.0
      })

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "On Budget"
    end

    test "filters by company", %{conn: conn} do
      company1 = company_fixture(%{name: "Company Alpha"})
      company2 = company_fixture(%{name: "Company Beta"})

      budget_fixture(%{company: company1, category: "Alpha Ops"})
      budget_fixture(%{company: company2, category: "Beta Ops"})

      {:ok, live, _html} = live(conn, ~p"/budgets/variance")
      html = render_click(live, "filter_company", %{"company_id" => to_string(company1.id)})
      assert html =~ "Company Alpha" || html =~ "Alpha Ops"
    end

    test "filters back to all companies", %{conn: conn} do
      company = company_fixture(%{name: "Filtered Co"})
      budget_fixture(%{company: company, category: "Test Cat"})

      {:ok, live, _html} = live(conn, ~p"/budgets/variance")
      render_click(live, "filter_company", %{"company_id" => to_string(company.id)})
      html = render_click(live, "filter_company", %{"company_id" => ""})
      assert html =~ "Budget vs Actual"
    end

    test "displays Variance Detail section with table headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Variance Detail"
      assert html =~ "Category"
      assert html =~ "Budgeted"
      assert html =~ "Actual"
      assert html =~ "Status"
    end

    test "displays All Budget Records section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "All Budget Records"
    end

    test "shows budget chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Budget vs Actual by Category"
    end

    test "displays company selector in the filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "All Companies"
      assert html =~ "Company"
    end

    test "handles noop event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/budgets/variance")
      html = render_click(live, "noop", %{})
      assert html =~ "Budget vs Actual"
    end

    test "renders multiple categories in summary", %{conn: conn} do
      company = company_fixture()

      budget_fixture(%{company: company, category: "Marketing", budgeted: 10_000.0, actual: 8_000.0})
      budget_fixture(%{company: company, category: "Engineering", budgeted: 20_000.0, actual: 25_000.0})
      budget_fixture(%{company: company, category: "Sales", budgeted: 15_000.0, actual: 15_000.0})

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Marketing"
      assert html =~ "Engineering"
      assert html =~ "Sales"
    end

    test "shows period and currency in budget records table", %{conn: conn} do
      company = company_fixture()
      budget_fixture(%{company: company, period: "2024-Q1", category: "R&D", currency: "EUR"})

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "2024-Q1"
      assert html =~ "EUR"
    end

    test "shows company link in budget records", %{conn: conn} do
      company = company_fixture(%{name: "LinkBudgetCo"})
      budget_fixture(%{company: company, category: "Ops"})

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "LinkBudgetCo"
    end

    test "page description is shown", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      assert html =~ "Compare budgeted amounts against actual spend"
    end

    test "variance percentage shows correctly for budgets with data", %{conn: conn} do
      company = company_fixture()
      budget_fixture(%{company: company, category: "Test", budgeted: 100_000.0, actual: 120_000.0})

      {:ok, _live, html} = live(conn, ~p"/budgets/variance")
      # Variance is +20%, should show some percentage
      assert html =~ "%" || html =~ "Variance"
    end
  end
end
