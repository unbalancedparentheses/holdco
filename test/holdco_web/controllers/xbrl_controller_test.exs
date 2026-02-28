defmodule HoldcoWeb.XbrlControllerTest do
  use HoldcoWeb.ConnCase, async: true

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /export/xbrl/:id" do
    test "returns XML with XBRL content", %{conn: conn} do
      company = company_fixture(%{name: "XBRL Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/xml"
    end

    test "includes XBRL namespace declarations", %{conn: conn} do
      company = company_fixture(%{name: "NS Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "xbrli:xbrl"
      assert body =~ "xmlns:xbrli"
      assert body =~ "xmlns:us-gaap"
    end

    test "includes company identifier", %{conn: conn} do
      company = company_fixture(%{name: "Identified Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "Identified Corp"
    end

    test "includes balance sheet elements", %{conn: conn} do
      company = company_fixture(%{name: "BS Corp"})
      account_fixture(%{company: company, account_type: "asset", code: "1000", name: "Cash"})
      account_fixture(%{company: company, account_type: "liability", code: "2000", name: "Loans"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "us-gaap:Assets"
      assert body =~ "us-gaap:Liabilities"
    end

    test "includes income statement elements", %{conn: conn} do
      company = company_fixture(%{name: "IS Corp"})
      account_fixture(%{company: company, account_type: "revenue", code: "4000", name: "Sales"})
      account_fixture(%{company: company, account_type: "expense", code: "5000", name: "Costs"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "us-gaap:Revenues"
      assert body =~ "us-gaap:CostsAndExpenses"
      assert body =~ "us-gaap:NetIncomeLoss"
    end

    test "sets content-disposition header for download", %{conn: conn} do
      company = company_fixture(%{name: "Download Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")

      disposition = get_resp_header(conn, "content-disposition") |> hd()
      assert disposition =~ "attachment"
      assert disposition =~ "xbrl.xml"
    end

    test "includes context and unit definitions", %{conn: conn} do
      company = company_fixture(%{name: "Context Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "xbrli:context"
      assert body =~ "xbrli:unit"
      assert body =~ "iso4217:USD"
    end

    test "escapes XML special characters in company name", %{conn: conn} do
      company = company_fixture(%{name: "A & B <Corp>"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "A &amp; B &lt;Corp&gt;"
    end

    test "includes equity elements in XBRL", %{conn: conn} do
      company = company_fixture(%{name: "Equity Corp"})
      account_fixture(%{company: company, account_type: "equity", code: "3000", name: "Common Stock"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "us-gaap:StockholdersEquity"
      assert body =~ "Common Stock"
    end

    test "includes individual account line comments", %{conn: conn} do
      company = company_fixture(%{name: "Line Corp"})
      account_fixture(%{company: company, account_type: "asset", code: "1100", name: "Accounts Receivable"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      # Account name should appear in XML comment
      assert body =~ "Accounts Receivable"
    end

    test "handles company with no accounts", %{conn: conn} do
      company = company_fixture(%{name: "Empty Accounts Corp"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "us-gaap:Assets"
      assert body =~ "us-gaap:Liabilities"
      assert body =~ "us-gaap:Revenues"
      assert body =~ "us-gaap:NetIncomeLoss"
      assert body =~ "0.0"
    end

    test "escapes special characters in account names inside XML comments", %{conn: conn} do
      company = company_fixture(%{name: "Special Chars Corp"})
      account_fixture(%{company: company, account_type: "asset", code: "1200", name: "R&D Equipment"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      # The account name in the comment should be escaped
      assert body =~ "R&amp;D Equipment"
    end

    test "includes context period with today's date", %{conn: conn} do
      company = company_fixture(%{name: "Date Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      today = Date.to_iso8601(Date.utc_today())
      assert body =~ today
    end

    test "includes dei namespace and SEC identifier scheme", %{conn: conn} do
      company = company_fixture(%{name: "Namespace Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "xmlns:dei"
      assert body =~ "http://www.sec.gov"
    end

    test "handles company name with quotes and apostrophes", %{conn: conn} do
      company = company_fixture(%{name: "O'Brien \"Test\" Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "O&apos;Brien"
      assert body =~ "&quot;Test&quot;"
    end

    test "content-disposition includes company name in filename", %{conn: conn} do
      company = company_fixture(%{name: "Filename Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")

      disposition = get_resp_header(conn, "content-disposition") |> hd()
      assert disposition =~ "Filename Corp"
    end

    test "both revenue and expense accounts map to correct elements when they have journal entries", %{conn: conn} do
      company = company_fixture(%{name: "RevExp Corp"})
      rev = account_fixture(%{company: company, account_type: "revenue", code: "4100", name: "Service Revenue"})
      exp = account_fixture(%{company: company, account_type: "expense", code: "5100", name: "Office Supplies"})

      # Create journal entries to make accounts show up in trial balance
      entry = journal_entry_fixture(%{company: company, date: "2024-01-01", description: "Rev and Exp"})
      journal_line_fixture(%{entry: entry, account: rev, debit: 0.0, credit: 1000.0})
      journal_line_fixture(%{entry: entry, account: exp, debit: 500.0, credit: 0.0})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "Service Revenue"
      assert body =~ "Office Supplies"
      assert body =~ "us-gaap:Revenues"
      assert body =~ "us-gaap:CostsAndExpenses"
    end

    test "XBRL output includes decimals attribute on value elements", %{conn: conn} do
      company = company_fixture(%{name: "Decimals Corp"})
      account_fixture(%{company: company, account_type: "asset", code: "1300", name: "Inventory"})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ ~s(decimals="2")
    end

    test "XBRL output has valid XML structure", %{conn: conn} do
      company = company_fixture(%{name: "XML Struct Corp"})
      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ ~s(<?xml version="1.0")
      assert body =~ "</xbrli:xbrl>"
    end

    test "handles multiple account types in balance sheet", %{conn: conn} do
      company = company_fixture(%{name: "Multi BS Corp"})
      asset_acct = account_fixture(%{company: company, account_type: "asset", code: "1000", name: "Cash"})
      liab_acct = account_fixture(%{company: company, account_type: "liability", code: "2000", name: "Payable"})
      equity_acct = account_fixture(%{company: company, account_type: "equity", code: "3000", name: "Retained"})

      entry = journal_entry_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: asset_acct, debit: 1000.0, credit: 0.0})
      journal_line_fixture(%{entry: entry, account: liab_acct, debit: 0.0, credit: 500.0})
      journal_line_fixture(%{entry: entry, account: equity_acct, debit: 0.0, credit: 500.0})

      conn = get(conn, ~p"/export/xbrl/#{company.id}")
      body = response(conn, 200)

      assert body =~ "Cash"
      assert body =~ "Payable"
      assert body =~ "Retained"
    end
  end
end
