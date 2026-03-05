defmodule HoldcoWeb.DebtMaturityLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
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

    test "renders liability with empty maturity date as No Maturity", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, status: "active", principal: 50_000.0, creditor: "Empty Date Creditor", maturity_date: ""})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Empty Date Creditor"
      assert html =~ "No Maturity"
    end

    test "renders liability with invalid maturity date as No Maturity", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, status: "active", principal: 50_000.0, creditor: "Bad Date Cred", maturity_date: "not-a-date"})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Bad Date Cred"
      assert html =~ "No Maturity"
    end

    test "5+ Years bucket for far future maturity", %{conn: conn} do
      company = company_fixture()
      far_future = Date.utc_today() |> Date.add(2200) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 200_000.0,
        maturity_date: far_future,
        creditor: "Far Future Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "5+ Years"
      assert html =~ "Far Future Bank"
    end

    test "1-3 Years bucket for medium term maturity", %{conn: conn} do
      company = company_fixture()
      mid_date = Date.utc_today() |> Date.add(600) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 150_000.0,
        maturity_date: mid_date,
        creditor: "Mid Term Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "1-3 Years"
      assert html =~ "Mid Term Bank"
    end

    test "renders composition chart with multiple liability types", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, status: "active", principal: 100_000.0, liability_type: "loan", creditor: "Loan Bank"})
      liability_fixture(%{company: company, status: "active", principal: 200_000.0, liability_type: "bond", creditor: "Bond Holder"})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Loan Bank"
      assert html =~ "Bond Holder"
    end

    test "past maturity dates are still in 0-1 year bucket", %{conn: conn} do
      company = company_fixture()
      past_date = Date.utc_today() |> Date.add(-30) |> Date.to_iso8601()

      liability_fixture(%{
        company: company,
        status: "active",
        principal: 50_000.0,
        maturity_date: past_date,
        creditor: "Past Due Bank"
      })

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      assert html =~ "Past Due Bank"
      assert html =~ "0-1 Year"
    end

    test "calculates avg maturity with invalid date entries", %{conn: conn} do
      company = company_fixture()
      valid_date = Date.utc_today() |> Date.add(365) |> Date.to_iso8601()

      liability_fixture(%{company: company, status: "active", principal: 100_000.0, maturity_date: valid_date})
      liability_fixture(%{company: company, status: "active", principal: 50_000.0, maturity_date: "bad-date"})

      {:ok, _live, html} = live(conn, ~p"/debt-maturity")
      # Should still compute avg maturity from valid entries
      assert html =~ "yr"
    end
  end
end
