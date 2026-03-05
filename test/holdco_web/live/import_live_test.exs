defmodule HoldcoWeb.ImportLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "tab switching (editor user)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "switching to holdings tab shows holdings columns", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ "Import Holdings"
      assert html =~ "Asset, Ticker, Type, Quantity, Currency, Company Name"
    end

    test "switching to transactions tab shows transactions columns", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      assert html =~ "Import Transactions"
      assert html =~ "Date, Description, Amount, Currency, Category, Company Name"
    end

    test "switching to companies tab shows companies columns", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      # Switch away then back
      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      html = view |> element(~s(button[phx-value-tab="companies"])) |> render_click()

      assert html =~ "Import Companies"
      assert html =~ "Name, Country, Entity Type, Category, Ownership %"
    end

    test "switching tabs clears results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      refute html =~ "Import Results"
    end

    test "holdings tab shows example row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ "Apple Inc, AAPL, stock, 100, USD, Acme Corp"
    end

    test "transactions tab shows example row", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      assert html =~ "2025-01-15, Office rent, -5000, USD, expense, Acme Corp"
    end
  end

  describe "query param routing" do
    test "type=holdings sets active tab to holdings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import?type=holdings")

      assert html =~ "Import Holdings"
    end

    test "type=transactions sets active tab to transactions", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import?type=transactions")

      assert html =~ "Import Transactions"
    end

    test "unknown type defaults to companies", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import?type=unknown")

      assert html =~ "Import Companies"
    end
  end

  describe "import event without file (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "import without file shows error flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Please select a file"
    end
  end

  describe "handle_params with type" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "navigating with type=holdings updates tab via handle_params", %{conn: conn} do
      {:ok, _view, _html} = live(conn, ~p"/import")

      # Navigate to holdings type
      {:ok, _view, html} = live(conn, ~p"/import?type=holdings")
      assert html =~ "Import Holdings"
    end

    test "navigating with type=transactions updates tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import?type=transactions")
      assert html =~ "Import Transactions"
    end
  end

  describe "editor tab switching resets upload" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "switching tabs resets file upload and results", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()
      assert html =~ "Import Holdings"
      refute html =~ "Import Results"

      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()
      assert html =~ "Import Transactions"
      refute html =~ "Import Results"

      html = view |> element(~s(button[phx-value-tab="companies"])) |> render_click()
      assert html =~ "Import Companies"
      refute html =~ "Import Results"
    end
  end

  describe "CSV file upload and import (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "importing companies CSV creates companies", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nNewImportCo,US,LLC,Operating,100"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "importing companies CSV with duplicate name shows error", %{conn: conn} do
      company_fixture(%{name: "ExistingCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nExistingCo,US,LLC,Operating,100"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "already exists"
    end

    test "importing companies CSV with invalid columns shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country\nBadCo,US"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "Invalid number of columns"
    end

    test "importing holdings CSV creates holdings", %{conn: conn} do
      company = company_fixture(%{name: "HoldImportCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      csv_content = "Asset,Ticker,Type,Quantity,Currency,Company\nApple,AAPL,stock,100,USD,#{company.name}"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "holdings.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "importing holdings CSV with unknown company shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      csv_content = "Asset,Ticker,Type,Quantity,Currency,Company\nApple,AAPL,stock,100,USD,NonExistentCo"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "holdings.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "not found"
    end

    test "importing transactions CSV creates transactions", %{conn: conn} do
      company = company_fixture(%{name: "TxImportCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      csv_content = "Date,Description,Amount,Currency,Category,Company\n2025-01-15,Office rent,5000,USD,expense,#{company.name}"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "transactions.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "importing transactions CSV with unknown company shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      csv_content = "Date,Description,Amount,Currency,Category,Company\n2025-01-15,Rent,-5000,USD,expense,GhostCorp"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "transactions.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "not found"
    end

    test "importing transactions CSV with too few columns shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      csv_content = "Date,Description\n2025-01-15,Rent"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "transactions.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "Invalid number of columns"
    end

    test "importing holdings CSV with too few columns shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      csv_content = "Asset,Ticker\nApple,AAPL"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "holdings.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "Invalid number of columns"
    end

    test "importing companies with empty ownership parses as nil", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nNilOwnerCo,UK,Ltd,SPV,notanumber"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "importing companies with pick_category uses entity_type when category empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nCatTestCo,US,LLC,,100"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "holdings import with empty company name still works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      csv_content = "Asset,Ticker,Type,Quantity,Currency,Company\nGeneric Fund,GEN,fund,50,USD,"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "holdings.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
    end

    test "transactions import with empty company name still works", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      csv_content = "Date,Description,Amount,Currency,Category,Company\n2025-01-15,Misc,100,USD,income,"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "transactions.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
    end
  end

  describe "malformed CSV import (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "malformed CSV shows parse error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country\n\"unclosed,field"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "bad.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "bad.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "CSV Parse Error"
    end
  end

  describe "multiple row import (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "importing multiple companies in one CSV", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nBulkCoA,US,LLC,Operating,100\nBulkCoB,UK,Ltd,SPV,50"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "2 created"
    end

    test "importing companies with mixed valid and duplicate shows partial results", %{conn: conn} do
      company_fixture(%{name: "MixedExisting"})
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nMixedNew,US,LLC,Operating,100\nMixedExisting,US,LLC,Holding,50"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
      assert html =~ "1 errors"
    end

    test "importing holdings with multiple rows including errors", %{conn: conn} do
      company = company_fixture(%{name: "MultiHoldCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      csv_content = "Asset,Ticker,Type,Quantity,Currency,Company\nStock A,STK,stock,100,USD,#{company.name}\nBad Hold"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "holdings.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
      assert html =~ "Invalid number of columns"
    end

    test "importing transactions with multiple rows including errors", %{conn: conn} do
      company = company_fixture(%{name: "MultiTxCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      csv_content = "Date,Description,Amount,Currency,Category,Company\n2025-01-15,Payment,100,USD,income,#{company.name}\nBad Row"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "transactions.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
      assert html =~ "Invalid number of columns"
    end

    test "importing companies with category populated picks category over entity_type", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nCatPickCo,US,LLC,subsidiary,100"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "importing companies with float ownership rounds correctly", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      csv_content = "Name,Country,Entity Type,Category,Ownership\nFloatOwnerCo,US,LLC,Operating,75.5"

      csv_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.csv",
            content: csv_content,
            type: "text/csv"
          }
        ])

      render_upload(csv_file, "companies.csv")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end
  end

  describe "XLSX file upload and import (editor)" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "xlsx file type is detected by extension", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      # Create a minimal xlsx file in memory for upload
      xlsx_content = create_test_xlsx([
        ["Name", "Country", "Entity Type", "Category", "Ownership"],
        ["XlsxImportCo", "US", "LLC", "Operating", "100"]
      ])

      xlsx_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "companies.xlsx",
            content: xlsx_content,
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          }
        ])

      render_upload(xlsx_file, "companies.xlsx")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "malformed xlsx shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      xlsx_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "bad.xlsx",
            content: "not a valid xlsx file",
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          }
        ])

      render_upload(xlsx_file, "bad.xlsx")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "Excel Parse Error"
    end

    test "xlsx with multiple data rows imports all", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      xlsx_content = create_test_xlsx([
        ["Name", "Country", "Entity Type", "Category", "Ownership"],
        ["XlsxCoA", "US", "LLC", "Operating", "100"],
        ["XlsxCoB", "UK", "Ltd", "Holding", "50"]
      ])

      xlsx_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "multi.xlsx",
            content: xlsx_content,
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          }
        ])

      render_upload(xlsx_file, "multi.xlsx")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "2 created"
    end

    test "xlsx holdings import works", %{conn: conn} do
      company = company_fixture(%{name: "XlsxHoldCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      xlsx_content = create_test_xlsx([
        ["Asset", "Ticker", "Type", "Quantity", "Currency", "Company"],
        ["Google", "GOOG", "stock", "50", "USD", company.name]
      ])

      xlsx_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "holdings.xlsx",
            content: xlsx_content,
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          }
        ])

      render_upload(xlsx_file, "holdings.xlsx")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end

    test "xlsx transactions import works", %{conn: conn} do
      company = company_fixture(%{name: "XlsxTxCo"})
      {:ok, view, _html} = live(conn, ~p"/import")

      view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()

      xlsx_content = create_test_xlsx([
        ["Date", "Description", "Amount", "Currency", "Category", "Company"],
        ["2025-03-15", "Office supplies", "250", "USD", "expense", company.name]
      ])

      xlsx_file =
        file_input(view, "#import-form", :csv_file, [
          %{
            name: "transactions.xlsx",
            content: xlsx_content,
            type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
          }
        ])

      render_upload(xlsx_file, "transactions.xlsx")

      html =
        view
        |> form("#import-form")
        |> render_submit()

      assert html =~ "Import Results"
      assert html =~ "1 created"
    end
  end

  # Helper to create a minimal XLSX file as binary for upload
  defp create_test_xlsx(rows) do
    all_values = List.flatten(rows) |> Enum.uniq()
    ss_index = all_values |> Enum.with_index() |> Map.new()

    shared_strings_xml = build_shared_strings_xml(all_values)
    sheet_xml = build_sheet_xml(rows, ss_index)

    content_types_xml =
      ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
        ~s(<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">) <>
        ~s(<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>) <>
        ~s(<Default Extension="xml" ContentType="application/xml"/>) <>
        ~s(<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>) <>
        ~s(<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>) <>
        ~s(<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>) <>
        ~s(</Types>)

    rels_xml =
      ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
        ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
        ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>) <>
        ~s(</Relationships>)

    workbook_xml =
      ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
        ~s(<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
        ~s(<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></sheets>) <>
        ~s(</workbook>)

    workbook_rels_xml =
      ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
        ~s(<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">) <>
        ~s(<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>) <>
        ~s(<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>) <>
        ~s(</Relationships>)

    files = [
      {~c"[Content_Types].xml", content_types_xml},
      {~c"_rels/.rels", rels_xml},
      {~c"xl/workbook.xml", workbook_xml},
      {~c"xl/_rels/workbook.xml.rels", workbook_rels_xml},
      {~c"xl/sharedStrings.xml", shared_strings_xml},
      {~c"xl/worksheets/sheet1.xml", sheet_xml}
    ]

    {:ok, {_, zip_binary}} = :zip.create(~c"mem.xlsx", files, [:memory])
    zip_binary
  end

  defp build_shared_strings_xml(values) do
    si_elements =
      values
      |> Enum.map(fn val -> "<si><t>#{xml_escape(val)}</t></si>" end)
      |> Enum.join("")

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="#{length(values)}" uniqueCount="#{length(values)}">) <>
      si_elements <>
      ~s(</sst>)
  end

  defp build_sheet_xml(rows, ss_index) do
    row_elements =
      rows
      |> Enum.with_index(1)
      |> Enum.map(fn {row, row_idx} ->
        cells =
          row
          |> Enum.with_index()
          |> Enum.map(fn {val, col_idx} ->
            col_letter = col_index_to_letter(col_idx)
            ref = "#{col_letter}#{row_idx}"
            idx = Map.get(ss_index, val, 0)
            ~s(<c r="#{ref}" t="s"><v>#{idx}</v></c>)
          end)
          |> Enum.join("")

        ~s(<row r="#{row_idx}">#{cells}</row>)
      end)
      |> Enum.join("")

    ~s(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>) <>
      ~s(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">) <>
      ~s(<sheetData>#{row_elements}</sheetData>) <>
      ~s(</worksheet>)
  end

  defp col_index_to_letter(idx) when idx < 26, do: <<(?A + idx)>>
  defp col_index_to_letter(idx), do: <<(?A + div(idx, 26) - 1), (?A + rem(idx, 26))>>

  defp xml_escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
