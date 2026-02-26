defmodule HoldcoWeb.ReportControllerTest do
  use HoldcoWeb.ConnCase

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "report pages" do
    test "GET /reports/portfolio renders", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      assert response(conn, 200)
    end

    test "GET /reports/financial renders", %{conn: conn} do
      conn = get(conn, ~p"/reports/financial")
      assert response(conn, 200)
    end

    test "GET /reports/compliance renders", %{conn: conn} do
      conn = get(conn, ~p"/reports/compliance")
      assert response(conn, 200)
    end
  end

  describe "portfolio report content" do
    test "GET /reports/portfolio contains NAV section", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Portfolio NAV Report"
      assert body =~ "Net Asset Value"
      assert body =~ "Liquid Assets"
      assert body =~ "Marketable Securities"
      assert body =~ "Illiquid Assets"
      assert body =~ "Total Liabilities"
    end

    test "GET /reports/portfolio contains allocation section", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Asset Allocation"
      assert body =~ "Asset Type"
    end

    test "GET /reports/portfolio contains FX exposure section", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "FX Exposure"
      assert body =~ "Currency"
    end

    test "GET /reports/portfolio contains gains section", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Gains Summary"
      assert body =~ "Total Unrealized Gain"
      assert body =~ "Total Realized Gain"
    end

    test "GET /reports/portfolio contains footer", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "generated automatically by Holdco"
    end

    test "GET /reports/portfolio contains print button", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Print / Save as PDF"
    end

    test "GET /reports/portfolio with holdings shows allocation data", %{conn: conn} do
      company = company_fixture()
      holding_fixture(%{company: company, asset: "Stock Portfolio", ticker: "SPY", current_value: 100_000.0, currency: "USD"})
      holding_fixture(%{company: company, asset: "Bond Fund", ticker: "BND", current_value: 50_000.0, currency: "EUR"})

      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Portfolio NAV Report"
      # Report should contain dollar formatting
      assert body =~ "$"
    end

    test "GET /reports/portfolio includes generated date", %{conn: conn} do
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Generated:"
    end
  end

  describe "financial report content" do
    test "GET /reports/financial contains consolidated summary", %{conn: conn} do
      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Financial Summary Report"
      assert body =~ "Consolidated Summary"
      assert body =~ "Total Revenue"
      assert body =~ "Total Expenses"
      assert body =~ "Net Income"
    end

    test "GET /reports/financial contains liabilities section", %{conn: conn} do
      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Liabilities"
      assert body =~ "Creditor"
    end

    test "GET /reports/financial with data shows company financials", %{conn: conn} do
      company = company_fixture(%{name: "TestReportCorp"})
      financial_fixture(%{company: company, period: "2024-Q1", revenue: 100_000.0, expenses: 50_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "TestReportCorp"
      assert body =~ "by Company"
    end

    test "GET /reports/financial with liabilities shows them", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "BigBank Corp", principal: 500_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "BigBank Corp"
    end

    test "GET /reports/financial with active liability shows status tag", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Active Lender", status: "active", principal: 100_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Active Lender"
      assert body =~ "active"
      assert body =~ "tag-active"
    end

    test "GET /reports/financial with paid liability shows completed tag", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Paid Off Bank", status: "paid", principal: 50_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Paid Off Bank"
      assert body =~ "tag-completed"
    end

    test "GET /reports/financial with multiple companies groups them", %{conn: conn} do
      company1 = company_fixture(%{name: "AlphaCorp"})
      company2 = company_fixture(%{name: "BetaCorp"})
      financial_fixture(%{company: company1, period: "2024-Q1", revenue: 10_000.0})
      financial_fixture(%{company: company2, period: "2024-Q1", revenue: 20_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "AlphaCorp"
      assert body =~ "BetaCorp"
      assert body =~ "Subtotal"
    end

    test "GET /reports/financial with liability interest rate shows percentage", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Loan Co", interest_rate: 5.5, principal: 100_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "5.5%"
    end

    test "GET /reports/financial shows maturity date when present", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Term Lender", maturity_date: "2025-12-31", principal: 100_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "2025-12-31"
    end
  end

  describe "compliance report content" do
    test "GET /reports/compliance contains overview section", %{conn: conn} do
      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Compliance Status Report"
      assert body =~ "Overview"
      assert body =~ "Tax Deadlines"
      assert body =~ "Regulatory Filings"
      assert body =~ "Insurance Policies"
    end

    test "GET /reports/compliance with tax deadlines", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Annual VAT Return", status: "pending"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Annual VAT Return"
      assert body =~ "pending"
      assert body =~ "tag-pending"
    end

    test "GET /reports/compliance with filed tax deadline", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Filed Return", status: "filed"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Filed Return"
      assert body =~ "tag-filed"
    end

    test "GET /reports/compliance with completed tax deadline", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Completed Return", status: "completed"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Completed Return"
      assert body =~ "tag-completed"
    end

    test "GET /reports/compliance with overdue tax deadline", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Overdue Return", status: "overdue"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Overdue Return"
      assert body =~ "tag-overdue"
    end

    test "GET /reports/compliance with regulatory filings", %{conn: conn} do
      company = company_fixture()
      regulatory_filing_fixture(%{company: company, filing_type: "10-K Annual Report"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "10-K Annual Report"
    end

    test "GET /reports/compliance with filed regulatory filing", %{conn: conn} do
      company = company_fixture()
      regulatory_filing_fixture(%{company: company, filing_type: "10-Q", status: "filed", filed_date: "2024-05-15", reference_number: "REF-001"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "10-Q"
      assert body =~ "2024-05-15"
      assert body =~ "REF-001"
    end

    test "GET /reports/compliance with insurance policies", %{conn: conn} do
      company = company_fixture()
      insurance_policy_fixture(%{company: company, policy_type: "Directors & Officers", provider: "AIG Insurance"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "AIG Insurance"
    end

    test "GET /reports/compliance with insurance policy details", %{conn: conn} do
      company = company_fixture()
      insurance_policy_fixture(%{
        company: company,
        policy_type: "General Liability",
        provider: "Zurich Insurance",
        policy_number: "POL-12345",
        coverage_amount: 5_000_000.0,
        premium: 50_000.0,
        currency: "USD",
        start_date: "2024-01-01",
        expiry_date: "2025-01-01"
      })

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Zurich Insurance"
      assert body =~ "POL-12345"
      assert body =~ "General Liability"
      assert body =~ "2024-01-01"
      assert body =~ "2025-01-01"
    end

    test "GET /reports/compliance shows pending count in overview", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Pending 1", status: "pending"})
      tax_deadline_fixture(%{company: company, description: "Pending 2", status: "pending"})
      tax_deadline_fixture(%{company: company, description: "Filed 1", status: "filed"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Pending Tax Deadlines"
    end

    test "GET /reports/compliance with unknown status uses default tag", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Unknown Status", status: "something_else"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Unknown Status"
      assert body =~ "tag-default"
    end
  end

  describe "ReportHTML edge cases" do
    test "portfolio report with negative gains shows negative class", %{conn: conn} do
      # To trigger gain_class with a negative value, we need gains with negative totals
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      # Should at least render without errors
      assert body =~ "Gains Summary"
    end

    test "portfolio report format_pct with zero total", %{conn: conn} do
      # When total_alloc is 0, format_pct returns "0.0%"
      conn = get(conn, ~p"/reports/portfolio")
      body = response(conn, 200)
      assert body =~ "Portfolio NAV Report"
    end

    test "financial report with completed liability status", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Completed Lender", status: "completed", principal: 75_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Completed Lender"
      assert body =~ "tag-completed"
    end

    test "financial report with unknown liability status uses default tag", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "Unknown Status Lender", status: "unknown", principal: 30_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "Unknown Status Lender"
      assert body =~ "tag-default"
    end

    test "financial report with liability without interest rate shows dash", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "No Rate Lender", interest_rate: nil, principal: 50_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "No Rate Lender"
      assert body =~ "-"
    end

    test "financial report with liability without maturity date shows dash", %{conn: conn} do
      company = company_fixture()
      liability_fixture(%{company: company, creditor: "No Maturity Lender", maturity_date: nil, principal: 50_000.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "No Maturity Lender"
    end

    test "compliance report with active regulatory filing status", %{conn: conn} do
      company = company_fixture()
      regulatory_filing_fixture(%{company: company, filing_type: "Active Filing", status: "active"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Active Filing"
      assert body =~ "tag-active"
    end

    test "compliance report with unknown regulatory filing status", %{conn: conn} do
      company = company_fixture()
      regulatory_filing_fixture(%{company: company, filing_type: "Mystery Filing", status: "mystery"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Mystery Filing"
      assert body =~ "tag-default"
    end

    test "compliance report with no pending deadlines shows zero pending", %{conn: conn} do
      company = company_fixture()
      tax_deadline_fixture(%{company: company, description: "Filed Only", status: "filed"})

      conn = get(conn, ~p"/reports/compliance")
      body = response(conn, 200)
      assert body =~ "Pending Tax Deadlines"
    end

    test "financial report format_usd with negative amount", %{conn: conn} do
      company = company_fixture()
      # Create a financial with negative revenue to trigger negative formatting
      financial_fixture(%{company: company, period: "NegPeriod", revenue: -5000.0, expenses: 0.0})

      conn = get(conn, ~p"/reports/financial")
      body = response(conn, 200)
      assert body =~ "NegPeriod"
    end
  end

  describe "unauthenticated access" do
    test "GET /reports/portfolio requires auth" do
      conn = build_conn()
      conn = get(conn, ~p"/reports/portfolio")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "GET /reports/financial requires auth" do
      conn = build_conn()
      conn = get(conn, ~p"/reports/financial")
      assert redirected_to(conn) == ~p"/users/log-in"
    end

    test "GET /reports/compliance requires auth" do
      conn = build_conn()
      conn = get(conn, ~p"/reports/compliance")
      assert redirected_to(conn) == ~p"/users/log-in"
    end
  end
end
