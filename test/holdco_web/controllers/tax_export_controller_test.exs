defmodule HoldcoWeb.TaxExportControllerTest do
  use HoldcoWeb.ConnCase, async: true

  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "tax_provisions_csv" do
    test "GET /export/tax-provisions.csv returns CSV with headers", %{conn: conn} do
      conn = get(conn, ~p"/export/tax-provisions.csv")
      body = response(conn, 200)
      assert body =~ "ID"
      assert body =~ "Company"
      assert body =~ "Jurisdiction"
      assert body =~ "Tax Type"
      assert body =~ "Amount"
    end

    test "GET /export/tax-provisions.csv includes tax payment data", %{conn: conn} do
      company = company_fixture(%{name: "Tax Corp"})
      tax_payment_fixture(%{company: company, jurisdiction: "US", tax_type: "income", amount: 50_000.0})

      conn = get(conn, ~p"/export/tax-provisions.csv")
      body = response(conn, 200)
      assert body =~ "Tax Corp"
      assert body =~ "US"
      assert body =~ "income"
      assert body =~ "50000"
    end

    test "GET /export/tax-provisions.csv filters by company_id", %{conn: conn} do
      company = company_fixture(%{name: "Filtered Tax Co"})
      tax_payment_fixture(%{company: company, jurisdiction: "UK", tax_type: "vat", amount: 10_000.0})
      _other = tax_payment_fixture(%{jurisdiction: "DE", tax_type: "income", amount: 20_000.0})

      conn = get(conn, ~p"/export/tax-provisions.csv?company_id=#{company.id}")
      body = response(conn, 200)
      assert body =~ "Filtered Tax Co"
      assert body =~ "UK"
    end

    test "GET /export/tax-provisions.csv handles empty company_id", %{conn: conn} do
      conn = get(conn, ~p"/export/tax-provisions.csv?company_id=")
      assert response(conn, 200)
    end
  end

  describe "deferred_taxes_csv" do
    test "GET /export/deferred-taxes.csv returns CSV with headers", %{conn: conn} do
      conn = get(conn, ~p"/export/deferred-taxes.csv")
      body = response(conn, 200)
      assert body =~ "Jurisdiction"
      assert body =~ "Tax Type"
      assert body =~ "Total Amount"
    end

    test "GET /export/deferred-taxes.csv groups by jurisdiction", %{conn: conn} do
      company = company_fixture(%{name: "Deferred Co"})
      tax_payment_fixture(%{company: company, jurisdiction: "US", tax_type: "income", amount: 30_000.0})
      tax_payment_fixture(%{company: company, jurisdiction: "US", tax_type: "income", amount: 20_000.0})

      conn = get(conn, ~p"/export/deferred-taxes.csv")
      body = response(conn, 200)
      assert body =~ "US"
      assert body =~ "income"
    end
  end

  describe "withholding_reclaims_csv" do
    test "GET /export/withholding-reclaims.csv returns CSV with headers", %{conn: conn} do
      conn = get(conn, ~p"/export/withholding-reclaims.csv")
      body = response(conn, 200)
      assert body =~ "ID"
      assert body =~ "Payment Type"
      assert body =~ "Country From"
      assert body =~ "Country To"
      assert body =~ "Gross Amount"
    end

    test "GET /export/withholding-reclaims.csv includes withholding data", %{conn: conn} do
      company = company_fixture(%{name: "WHT Corp"})

      withholding_tax_fixture(%{
        company: company,
        payment_type: "dividend",
        country_from: "US",
        country_to: "UK",
        gross_amount: 100_000.0,
        rate: 0.15,
        tax_amount: 15_000.0
      })

      conn = get(conn, ~p"/export/withholding-reclaims.csv")
      body = response(conn, 200)
      assert body =~ "WHT Corp"
      assert body =~ "dividend"
      assert body =~ "100000"
    end

    test "GET /export/withholding-reclaims.csv filters by company_id", %{conn: conn} do
      company = company_fixture(%{name: "WHT Filter"})
      withholding_tax_fixture(%{company: company, payment_type: "interest"})

      conn = get(conn, ~p"/export/withholding-reclaims.csv?company_id=#{company.id}")
      body = response(conn, 200)
      assert body =~ "WHT Filter"
    end
  end

  describe "k1_reports_csv" do
    test "GET /export/k1-reports.csv returns CSV with headers", %{conn: conn} do
      conn = get(conn, ~p"/export/k1-reports.csv")
      body = response(conn, 200)
      assert body =~ "Company"
      assert body =~ "Country"
      assert body =~ "Ownership %"
      assert body =~ "Total Dividends"
      assert body =~ "Total Contributions"
    end

    test "GET /export/k1-reports.csv includes K-1 data", %{conn: conn} do
      company = company_fixture(%{name: "K1 Corp"})
      dividend_fixture(%{company: company, amount: 25_000.0})
      capital_contribution_fixture(%{company: company, amount: 10_000.0})

      conn = get(conn, ~p"/export/k1-reports.csv")
      body = response(conn, 200)
      assert body =~ "K1 Corp"
      assert body =~ "25000"
      assert body =~ "10000"
    end

    test "GET /export/k1-reports.csv excludes companies with zero activity", %{conn: conn} do
      company_fixture(%{name: "Zero Activity Co"})

      conn = get(conn, ~p"/export/k1-reports.csv")
      body = response(conn, 200)
      refute body =~ "Zero Activity Co"
    end
  end

  describe "tax_package_zip" do
    test "GET /export/tax-package.zip returns a ZIP file", %{conn: conn} do
      conn = get(conn, ~p"/export/tax-package.zip")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "tax-package.zip"
    end

    test "GET /export/tax-package.zip contains all 4 CSV files", %{conn: conn} do
      # Create some data so CSVs are non-trivial
      company = company_fixture(%{name: "Zip Corp"})
      tax_payment_fixture(%{company: company})
      withholding_tax_fixture(%{company: company})
      dividend_fixture(%{company: company})

      conn = get(conn, ~p"/export/tax-package.zip")
      zip_data = response(conn, 200)

      {:ok, files} = :zip.unzip(zip_data, [:memory])
      filenames = Enum.map(files, fn {name, _content} -> to_string(name) end)

      assert "tax-provisions.csv" in filenames
      assert "deferred-taxes.csv" in filenames
      assert "withholding-reclaims.csv" in filenames
      assert "k1-reports.csv" in filenames
    end

    test "GET /export/tax-package.zip with company_id filter", %{conn: conn} do
      company = company_fixture()

      conn = get(conn, ~p"/export/tax-package.zip?company_id=#{company.id}")
      assert response(conn, 200)
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
    end
  end

  describe "authentication" do
    test "all tax export endpoints require authentication" do
      conn = build_conn()

      for path <- [
        ~p"/export/tax-provisions.csv",
        ~p"/export/deferred-taxes.csv",
        ~p"/export/withholding-reclaims.csv",
        ~p"/export/k1-reports.csv",
        ~p"/export/tax-package.zip"
      ] do
        resp = get(conn, path)
        assert resp.status in [302, 401], "Expected redirect for #{path}"
      end
    end
  end
end
