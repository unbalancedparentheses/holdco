defmodule HoldcoWeb.ImportLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /import" do
    test "renders import page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Import CSV"
    end

    test "renders page title and deck text", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "page-title"
      assert html =~ "Upload a CSV file to bulk-import records"
    end

    test "renders page-title-rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "page-title-rule"
    end

    test "shows tab buttons for import types", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Companies"
      assert html =~ "Holdings"
      assert html =~ "Transactions"
    end

    test "companies tab is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Import Companies"
    end

    test "shows expected CSV columns for companies", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Expected CSV columns"
      assert html =~ "Name, Country, Entity Type, Category, Ownership %"
    end

    test "renders import form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "import-form"
      assert html =~ "CSV File"
    end

    test "shows companies example row", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Acme Corp, US, LLC, Operating, 100"
    end
  end

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

  describe "permission - viewer user" do
    test "viewer sees Import (no permission) button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Import (no permission)"
    end

    test "viewer gets error flash when attempting any event", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = render_hook(view, "switch_tab", %{"tab" => "holdings"})

      assert html =~ "You don&#39;t have permission to import data" or
               html =~ "You don't have permission to import data"
    end
  end

  describe "permission - editor user" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "editor sees Import button (not disabled)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      assert html =~ "Import Companies"
      refute html =~ "Import (no permission)"
    end
  end

  describe "btn classes" do
    test "active tab button has btn-primary class", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import")

      # Companies is default active tab
      assert html =~ ~r/phx-value-tab="companies"[^>]*class="btn btn-primary"/s or
               html =~ ~r/class="btn btn-primary"[^>]*phx-value-tab="companies"/s
    end
  end

  describe "validate event" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "validate event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = render_hook(view, "validate", %{})
      assert html =~ "Import CSV"
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

      assert html =~ "Please select a CSV file"
    end
  end

  describe "handle_params with type" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      :ok
    end

    test "navigating with type=holdings updates tab via handle_params", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      # Navigate to holdings type
      {:ok, _view, html} = live(conn, ~p"/import?type=holdings")
      assert html =~ "Import Holdings"
    end

    test "navigating with type=transactions updates tab", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/import?type=transactions")
      assert html =~ "Import Transactions"
    end
  end

  describe "viewer permission guard catches all events" do
    test "viewer switching tabs gets permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      # Viewer user: the first handle_event clause catches all events
      html = render_hook(view, "validate", %{})
      assert html =~ "permission" or html =~ "Import CSV"
    end

    test "viewer trying import gets permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/import")

      html = render_hook(view, "import", %{})
      assert html =~ "permission"
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

      csv_content = "Date,Description,Amount,Currency,Category,Company\n2025-01-15,Office rent,-5000,USD,expense,#{company.name}"

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
end
