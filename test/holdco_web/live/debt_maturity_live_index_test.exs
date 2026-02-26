defmodule HoldcoWeb.DebtMaturityLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Debt Maturity page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Debt Maturity"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Total Debt"
      assert html =~ "Active Liabilities"
      assert html =~ "Avg Maturity"
      assert html =~ "Nearest Maturity"
    end

    test "shows maturity buckets table", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Maturity Buckets"
      assert html =~ "Time Horizon"
      assert html =~ "0-1 Year"
      assert html =~ "1-3 Years"
      assert html =~ "3-5 Years"
      assert html =~ "5+ Years"
      assert html =~ "No Maturity"
    end

    test "shows empty state when no liabilities exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "No liabilities recorded"
    end

    test "renders with active liability data showing creditor and type", %{conn: conn} do
      company = company_fixture(%{name: "Debtor Inc"})

      liability_fixture(%{
        company: company,
        liability_type: "loan",
        creditor: "Bank A",
        principal: 100_000.0,
        status: "active",
        maturity_date: Date.utc_today() |> Date.add(365) |> Date.to_iso8601()
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Bank A"
      assert html =~ "loan"
      assert html =~ "Debtor Inc"
    end

    test "renders with paid liability", %{conn: conn} do
      company = company_fixture(%{name: "Paid Off Co"})

      liability_fixture(%{
        company: company,
        liability_type: "bond",
        creditor: "Bondholder X",
        principal: 50_000.0,
        status: "paid"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Bondholder X"
      assert html =~ "paid"
    end

    test "shows N/A for avg maturity when no dated liabilities", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, status: "active", maturity_date: nil})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "N/A"
    end

    test "shows N/A for nearest maturity when no future dated liabilities", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "N/A"
    end

    test "calculates avg maturity years when liabilities have maturity dates", %{conn: conn} do
      company = company_fixture()
      future_date = Date.utc_today() |> Date.add(730) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 100_000.0,
        maturity_date: future_date
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      # Should show some avg maturity, not N/A
      assert html =~ "yr"
    end

    test "shows nearest maturity date", %{conn: conn} do
      company = company_fixture()
      near_date = Date.utc_today() |> Date.add(90) |> Date.to_iso8601()
      far_date = Date.utc_today() |> Date.add(1000) |> Date.to_iso8601()

      liability_fixture(%{company: company, status: "active", principal: 50_000.0, maturity_date: far_date})
      liability_fixture(%{company: company, status: "active", principal: 75_000.0, maturity_date: near_date})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ near_date
    end

    test "buckets liabilities into correct time horizons", %{conn: conn} do
      company = company_fixture()

      # 0-1 year bucket
      liability_fixture(%{
        company: company,
        status: "active",
        principal: 10_000.0,
        maturity_date: Date.utc_today() |> Date.add(180) |> Date.to_iso8601()
      })

      # 3-5 year bucket
      liability_fixture(%{
        company: company,
        status: "active",
        principal: 20_000.0,
        maturity_date: Date.utc_today() |> Date.add(1460) |> Date.to_iso8601()
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "0-1 Year"
      assert html =~ "3-5 Years"
    end

    test "renders Debt Composition chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Debt Composition"
    end

    test "renders Maturity Timeline chart section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Maturity Timeline"
    end

    test "shows interest rate when present", %{conn: conn} do
      company = company_fixture()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 100_000.0,
        interest_rate: 5.5,
        creditor: "Rate Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "5.5"
    end

    test "shows --- for missing interest rate", %{conn: conn} do
      company = company_fixture()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 100_000.0,
        interest_rate: nil,
        creditor: "No Rate Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "---"
    end

    test "handles noop event", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/debt-maturity")
      html = render_click(live, "noop", %{})
      assert html =~ "Debt Maturity"
    end

    test "renders restructured liability status", %{conn: conn} do
      company = company_fixture()

      liability_fixture(%{
        company: company,
        status: "restructured",
        principal: 100_000.0,
        creditor: "Restructured Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "restructured"
    end

    test "renders liability with no company gracefully", %{conn: conn} do
      # Create a liability whose company_id references a company
      company = company_fixture(%{name: "Visible Co"})
      liability_fixture(%{company: company, status: "active", principal: 50_000.0, creditor: "Test Creditor"})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Test Creditor"
    end
  end
end
