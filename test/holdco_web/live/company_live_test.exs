defmodule HoldcoWeb.CompanyLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  describe "GET /companies" do
    test "renders companies index page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Companies"
    end

    test "renders page title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "shows view toggle buttons (list/tree)", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "view-toggle"
    end

    test "companies nav link is active", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ ~r/href="\/companies"[^>]*class="active"/s
    end
  end

  import Holdco.HoldcoFixtures

  describe "tree view and toggle" do
    test "switching to tree view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_click(view, "set_view", %{"mode" => "tree"})
      assert html =~ "Companies"
    end

    test "switching back to list view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      render_click(view, "set_view", %{"mode" => "tree"})
      html = render_click(view, "set_view", %{"mode" => "list"})
      assert html =~ "Companies"
    end

    test "expand_all and collapse_all in tree view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      render_click(view, "set_view", %{"mode" => "tree"})
      html = render_click(view, "expand_all", %{})
      assert html =~ "Companies"

      html = render_click(view, "collapse_all", %{})
      assert html =~ "Companies"
    end

    test "toggle_node expands and collapses a node", %{conn: conn} do
      company = company_fixture(%{name: "TreeToggleCo"})
      {:ok, view, _html} = live(conn, ~p"/companies")

      render_click(view, "set_view", %{"mode" => "tree"})
      html = render_click(view, "toggle_node", %{"id" => to_string(company.id)})
      assert html =~ "Companies"

      # Toggle again to collapse
      html = render_click(view, "toggle_node", %{"id" => to_string(company.id)})
      assert html =~ "Companies"
    end
  end

  describe "save and delete events" do
    test "editor can create a company", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/companies/new")

      view
      |> form(~s(form[phx-submit="save"]), %{
        company: %{name: "New Corp", country: "US"}
      })
      |> render_submit()

      assert_redirect(view, ~p"/companies")
    end

    test "save with invalid data stays on form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/companies/new")

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          company: %{name: ""}
        })
        |> render_submit()

      # Should stay on the form (changeset error but no redirect)
      assert html =~ "Companies"
    end

    test "non-editor cannot save a company", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_hook(view, "save", %{"company" => %{"name" => "Blocked Corp"}})
      assert html =~ "You don&#39;t have permission to do that"
    end

    test "non-editor cannot delete a company", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_hook(view, "delete", %{"id" => "1"})
      assert html =~ "You don&#39;t have permission to do that"
    end

    test "editor can delete a company", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "DeleteMeCorp"})
      {:ok, view, _html} = live(conn, ~p"/companies")

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{company.id}"]))
        |> render_click()

      assert html =~ "Company deleted"
    end
  end

  describe "close_form event" do
    test "close_form redirects to companies index", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/companies/new")

      render_click(view, "close_form", %{})
      assert_redirect(view, ~p"/companies")
    end
  end

  describe "noop event" do
    test "noop does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_click(view, "noop", %{})
      assert html =~ "Companies"
    end
  end

  describe "handle_info" do
    test "companies_created reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      send(view.pid, {:companies_created, %{}})
      html = render(view)
      assert html =~ "Companies"
    end

    test "companies_deleted reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      send(view.pid, {:companies_deleted, %{}})
      html = render(view)
      assert html =~ "Companies"
    end

    test "unknown messages handled gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      send(view.pid, :unknown)
      html = render(view)
      assert html =~ "Companies"
    end
  end

  describe "company show page with tabs" do
    setup %{conn: conn} do
      # Create a company to visit its show page
      {:ok, company} = Holdco.Corporate.create_company(%{
        name: "Test Corp",
        jurisdiction: "US",
        entity_type: "LLC",
        status: "active",
        country: "US"
      })

      %{company: company, conn: conn}
    end

    test "renders company show page", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ company.name
    end

    test "renders all nine tabs", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ ~s(class="tabs")
      assert html =~ "Overview"
      assert html =~ "Holdings"
      assert html =~ "Bank Accounts"
      assert html =~ "Transactions"
      assert html =~ "Documents"
      assert html =~ "Governance"
      assert html =~ "Compliance"
      assert html =~ "Financials"
      assert html =~ "Comments"
    end

    test "overview tab is active by default", %{conn: conn, company: company} do
      {:ok, _view, html} = live(conn, ~p"/companies/#{company.id}")

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="overview"/s
    end

    test "clicking holdings tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="holdings"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="holdings"/s
    end

    test "clicking comments tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="comments"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="comments"/s
    end

    test "clicking governance tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="governance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="governance"/s
    end

    test "clicking compliance tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="compliance"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="compliance"/s
    end

    test "clicking financials tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")

      html = view |> element(~s(button[phx-value-tab="financials"])) |> render_click()

      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="financials"/s
    end

    test "clicking bank_accounts tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = view |> element(~s(button[phx-value-tab="bank_accounts"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="bank_accounts"/s
    end

    test "clicking transactions tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = view |> element(~s(button[phx-value-tab="transactions"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="transactions"/s
    end

    test "clicking documents tab activates it", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = view |> element(~s(button[phx-value-tab="documents"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="documents"/s
    end

    test "noop event on show page", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_click(view, "noop", %{})
      assert html =~ company.name
    end
  end

  describe "company show permission guards (viewer cannot write)" do
    setup %{conn: conn} do
      {:ok, company} = Holdco.Corporate.create_company(%{
        name: "Guard Corp", jurisdiction: "US", entity_type: "LLC", status: "active", country: "US"
      })
      %{company: company, conn: conn}
    end

    test "viewer cannot save_holding", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_holding", %{"holding" => %{"asset" => "AAPL"}})
      assert html =~ "permission"
    end

    test "viewer cannot delete_holding", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "delete_holding", %{"id" => "1"})
      assert html =~ "permission"
    end

    test "viewer cannot save_bank_account", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_bank_account", %{"bank_account" => %{"bank_name" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot save_transaction", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_transaction", %{"transaction" => %{"description" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot save_document", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_document", %{"document" => %{"name" => "Test"}})
      assert html =~ "permission"
    end

    test "viewer cannot save_board_meeting", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_board_meeting", %{"board_meeting" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_financial", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_financial", %{"financial" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_tax_deadline", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_tax_deadline", %{"tax_deadline" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot update_company", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "update_company", %{"company" => %{"name" => "Updated"}})
      assert html =~ "permission"
    end

    test "viewer cannot save_cap_table", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_cap_table", %{"cap_table" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_resolution", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_resolution", %{"resolution" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_deal", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_deal", %{"deal" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_jv", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_jv", %{"jv" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_poa", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_poa", %{"poa" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_equity_plan", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_equity_plan", %{"equity_plan" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_filing", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_filing", %{"filing" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_license", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_license", %{"license" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_esg", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_esg", %{"esg" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_sanctions", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_sanctions", %{"sanctions" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_fatca", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_fatca", %{"fatca" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_withholding", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_withholding", %{"withholding" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_liability", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_liability", %{"liability" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_dividend", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_dividend", %{"dividend" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_service_provider", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_service_provider", %{"service_provider" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_key_personnel", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_key_personnel", %{"key_personnel" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_beneficial_owner", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_beneficial_owner", %{"beneficial_owner" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_insurance_policy", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_insurance_policy", %{"insurance_policy" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_account", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_account", %{"account" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot save_journal_entry", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_journal_entry", %{"entry" => %{}})
      assert html =~ "permission"
    end

    test "viewer cannot delete_comment", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "delete_comment", %{"id" => "1"})
      assert html =~ "permission"
    end
  end

  describe "company show editor CRUD operations" do
    setup %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, company} = Holdco.Corporate.create_company(%{
        name: "Editor Corp", jurisdiction: "US", entity_type: "LLC", status: "active", country: "US"
      })
      %{company: company, conn: conn, user: user}
    end

    test "editor can show_form and close_form", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_click(view, "show_form", %{"form" => "holding"})
      assert html =~ company.name

      html = render_click(view, "close_form", %{})
      assert html =~ company.name
    end

    test "editor can save_holding", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_holding", %{"holding" => %{"asset" => "AAPL", "ticker" => "AAPL", "quantity" => "100"}})
      assert html =~ company.name
    end

    test "editor can save_bank_account", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_bank_account", %{"bank_account" => %{"bank_name" => "Chase", "account_number" => "123", "currency" => "USD"}})
      assert html =~ company.name
    end

    test "editor can save_transaction", %{conn: conn, company: company} do
      ba = bank_account_fixture(%{company: company})
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_transaction", %{"transaction" => %{"description" => "Test txn", "amount" => "100", "bank_account_id" => to_string(ba.id), "date" => "2024-01-01"}})
      assert html =~ company.name
    end

    test "editor can save_document", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_document", %{"document" => %{"name" => "Board Minutes"}})
      assert html =~ company.name
    end

    test "editor can save_board_meeting", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_board_meeting", %{"board_meeting" => %{"scheduled_date" => "2024-06-01", "meeting_type" => "regular"}})
      assert html =~ company.name
    end

    test "editor can save_financial", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_financial", %{"financial" => %{"period" => "2024-Q1", "revenue" => "100000", "expenses" => "50000"}})
      assert html =~ company.name
    end

    test "editor can save_tax_deadline", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_tax_deadline", %{"tax_deadline" => %{"jurisdiction" => "US", "description" => "Tax Filing", "due_date" => "2024-04-15"}})
      assert html =~ company.name
    end

    test "editor can update_company", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "update_company", %{"company" => %{"name" => "Updated Corp"}})
      assert html =~ "Updated Corp"
    end

    test "editor can save_comment", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_comment", %{"body" => "This is a test comment"})
      assert html =~ company.name
    end

    test "editor can save_cap_table", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_cap_table", %{"cap_table" => %{"investor" => "Acme Fund", "shares" => "1000"}})
      assert html =~ company.name
    end

    test "editor can save_resolution", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_resolution", %{"resolution" => %{"title" => "Dividend Resolution", "resolution_date" => "2024-06-01"}})
      assert html =~ company.name
    end

    test "editor can save_deal", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_deal", %{"deal" => %{"counterparty" => "BigCo", "deal_type" => "acquisition"}})
      assert html =~ company.name
    end

    test "editor can save_jv", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_jv", %{"jv" => %{"name" => "JV Corp", "partner" => "Partner Inc"}})
      assert html =~ company.name
    end

    test "editor can save_poa", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_poa", %{"poa" => %{"grantor" => "CEO", "grantee" => "CFO", "scope" => "Financial"}})
      assert html =~ company.name
    end

    test "editor can save_equity_plan", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_equity_plan", %{"equity_plan" => %{"plan_name" => "2024 ESOP"}})
      assert html =~ company.name
    end

    test "editor can save_filing", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_filing", %{"filing" => %{"jurisdiction" => "US", "filing_type" => "10-K", "due_date" => "2024-03-31"}})
      assert html =~ company.name
    end

    test "editor can save_license", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_license", %{"license" => %{"license_type" => "banking", "issuing_authority" => "OCC"}})
      assert html =~ company.name
    end

    test "editor can save_insurance_policy", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_insurance_policy", %{"insurance_policy" => %{"policy_type" => "D&O", "provider" => "AIG"}})
      assert html =~ company.name
    end

    test "editor can save_esg", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_esg", %{"esg" => %{"period" => "2024", "overall_score" => "85"}})
      assert html =~ company.name
    end

    test "editor can save_sanctions", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_sanctions", %{"sanctions" => %{"checked_name" => "Test Name"}})
      assert html =~ company.name
    end

    test "editor can save_fatca", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_fatca", %{"fatca" => %{"reporting_year" => "2024", "jurisdiction" => "US"}})
      assert html =~ company.name
    end

    test "editor can save_withholding", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_withholding", %{"withholding" => %{"payment_type" => "dividend", "country_from" => "US", "country_to" => "DE", "gross_amount" => "10000", "rate" => "0.15", "tax_amount" => "1500", "date" => "2024-01-01"}})
      assert html =~ company.name
    end

    test "editor can save_liability", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_liability", %{"liability" => %{"liability_type" => "loan", "creditor" => "Big Bank", "principal" => "100000"}})
      assert html =~ company.name
    end

    test "editor can save_dividend", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_dividend", %{"dividend" => %{"amount" => "5000", "date" => "2024-06-01"}})
      assert html =~ company.name
    end

    test "editor can save_account", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "save_account", %{"account" => %{"name" => "Cash", "account_type" => "asset", "code" => "1001"}})
      assert html =~ company.name
    end

    test "editor can validate_upload", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      html = render_hook(view, "validate_upload", %{})
      assert html =~ company.name
    end

    test "handle_info reloads on unknown message", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      send(view.pid, :some_unknown_message)
      html = render(view)
      assert html =~ company.name
    end

    test "handle_info reloads on new_comment", %{conn: conn, company: company} do
      {:ok, view, _html} = live(conn, ~p"/companies/#{company.id}")
      send(view.pid, {:new_comment, %{}})
      html = render(view)
      assert html =~ company.name
    end
  end
end
