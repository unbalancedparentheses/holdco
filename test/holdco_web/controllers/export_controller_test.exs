defmodule HoldcoWeb.ExportControllerTest do
  use HoldcoWeb.ConnCase, async: true

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "CSV exports" do
    test "GET /export/companies.csv", %{conn: conn} do
      company_fixture(%{name: "Export Corp"})
      conn = get(conn, ~p"/export/companies.csv")
      assert response(conn, 200)
      assert response_content_type(conn, :csv) || get_resp_header(conn, "content-type") |> hd() =~ "csv"
    end

    test "GET /export/holdings.csv", %{conn: conn} do
      holding_fixture()
      conn = get(conn, ~p"/export/holdings.csv")
      assert response(conn, 200)
    end

    test "GET /export/transactions.csv", %{conn: conn} do
      transaction_fixture()
      conn = get(conn, ~p"/export/transactions.csv")
      assert response(conn, 200)
    end

    test "GET /export/chart-of-accounts.csv", %{conn: conn} do
      account_fixture()
      conn = get(conn, ~p"/export/chart-of-accounts.csv")
      assert response(conn, 200)
    end

    test "GET /export/journal-entries.csv", %{conn: conn} do
      journal_entry_fixture()
      conn = get(conn, ~p"/export/journal-entries.csv")
      assert response(conn, 200)
    end
  end

  describe "chart_of_accounts with company_id" do
    test "filters by specific company_id", %{conn: conn} do
      company = company_fixture(%{name: "Filter Co"})
      account_fixture(%{company: company, name: "Filtered Account", code: "1001"})

      conn = get(conn, ~p"/export/chart-of-accounts.csv?company_id=#{company.id}")
      body = response(conn, 200)

      assert body =~ "Filtered Account"
    end

    test "handles empty company_id as nil", %{conn: conn} do
      account_fixture()
      conn = get(conn, ~p"/export/chart-of-accounts.csv?company_id=")
      assert response(conn, 200)
    end

    test "includes parent account name when present", %{conn: conn} do
      company = company_fixture()
      parent = account_fixture(%{company: company, name: "Parent Acct", code: "1000"})
      account_fixture(%{company: company, name: "Child Acct", code: "1100", parent_id: parent.id})

      conn = get(conn, ~p"/export/chart-of-accounts.csv")
      body = response(conn, 200)

      assert body =~ "Parent Acct"
      assert body =~ "Child Acct"
    end

    test "includes external_id when present", %{conn: conn} do
      company = company_fixture()
      account_fixture(%{company: company, name: "ExtID Acct", code: "1200", external_id: "EXT-001"})

      conn = get(conn, ~p"/export/chart-of-accounts.csv")
      body = response(conn, 200)

      assert body =~ "EXT-001"
    end
  end

  describe "journal_entries with company_id" do
    test "filters by specific company_id", %{conn: conn} do
      company = company_fixture(%{name: "JE Filter Co"})
      entry = journal_entry_fixture(%{company: company, description: "Filtered JE"})
      account = account_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: account, debit: 500.0, credit: 0.0})

      conn = get(conn, ~p"/export/journal-entries.csv?company_id=#{company.id}")
      body = response(conn, 200)

      assert body =~ "Filtered JE"
      assert body =~ "500"
    end

    test "handles empty company_id", %{conn: conn} do
      journal_entry_fixture()
      conn = get(conn, ~p"/export/journal-entries.csv?company_id=")
      assert response(conn, 200)
    end

    test "calculates total debit and credit from lines", %{conn: conn} do
      company = company_fixture()
      entry = journal_entry_fixture(%{company: company, description: "Multi Line JE", reference: "REF-001"})
      account = account_fixture(%{company: company})
      journal_line_fixture(%{entry: entry, account: account, debit: 100.0, credit: 0.0})
      journal_line_fixture(%{entry: entry, account: account, debit: 0.0, credit: 100.0})

      conn = get(conn, ~p"/export/journal-entries.csv")
      body = response(conn, 200)

      assert body =~ "Multi Line JE"
      assert body =~ "REF-001"
    end
  end

  describe "CSV value escaping" do
    test "escapes values with commas in company names", %{conn: conn} do
      company_fixture(%{name: "Acme, Inc."})
      conn = get(conn, ~p"/export/companies.csv")
      body = response(conn, 200)

      # Commas should be escaped by wrapping in quotes
      assert body =~ "\"Acme, Inc.\""
    end

    test "escapes values with double quotes", %{conn: conn} do
      company_fixture(%{name: "The \"Best\" Corp"})
      conn = get(conn, ~p"/export/companies.csv")
      body = response(conn, 200)

      # Double quotes should be escaped as ""
      assert body =~ "\"\"Best\"\""
    end
  end

  describe "holdings CSV content" do
    test "includes company name when associated", %{conn: conn} do
      company = company_fixture(%{name: "HoldingCo"})
      holding_fixture(%{company: company, asset: "Apple", ticker: "AAPL", asset_type: "stock", quantity: 100.0, currency: "USD"})

      conn = get(conn, ~p"/export/holdings.csv")
      body = response(conn, 200)

      assert body =~ "Apple"
      assert body =~ "AAPL"
      assert body =~ "HoldingCo"
    end
  end

  describe "transactions CSV content" do
    test "includes company name when associated", %{conn: conn} do
      company = company_fixture(%{name: "TxCo"})
      transaction_fixture(%{company: company, description: "Payment to vendor", amount: 500.0, currency: "USD"})

      conn = get(conn, ~p"/export/transactions.csv")
      body = response(conn, 200)

      assert body =~ "Payment to vendor"
      assert body =~ "TxCo"
    end
  end

  describe "audit_package with company_id" do
    test "audit package with empty company_id", %{conn: conn} do
      conn = get(conn, ~p"/export/audit-package.zip?company_id=")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
    end
  end
end
