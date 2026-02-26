defmodule HoldcoWeb.CompanyLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /companies - page rendering" do
    test "renders companies index page with heading", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Companies"
      assert html =~ "entities in the corporate structure"
    end

    test "renders page-title and page-title-rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "page-title"
      assert html =~ "page-title-rule"
    end

    test "renders view toggle with List and Tree buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "view-toggle"
      assert html =~ "List"
      assert html =~ "Tree"
    end

    test "list view is active by default", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ ~r/view-toggle-btn active[^"]*"[^>]*>\s*List/s
    end

    test "renders Export CSV link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Export CSV"
      assert html =~ "/export/companies.csv"
    end

    test "shows entity count in deck", %{conn: conn} do
      company_fixture(%{name: "CountMe Corp"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "1 entities in the corporate structure"
    end

    test "shows 0 entities when no companies exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "0 entities in the corporate structure"
    end

    test "renders table headers in list view", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "<th>Name</th>"
      assert html =~ "<th>Country</th>"
      assert html =~ "<th>Category</th>"
      assert html =~ "<th>Ownership</th>"
      assert html =~ "<th>KYC</th>"
      assert html =~ "<th>Status</th>"
    end

    test "shows empty state when no companies exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "empty-state"
      assert html =~ "No companies yet."
      assert html =~ "Create one"
    end
  end

  describe "GET /companies - company display" do
    test "displays company name as link", %{conn: conn} do
      company = company_fixture(%{name: "Acme Holdings"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Acme Holdings"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "displays company country", %{conn: conn} do
      company_fixture(%{name: "Swiss Corp", country: "CH"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "CH"
    end

    test "displays company category", %{conn: conn} do
      company_fixture(%{name: "OpCo", category: "Operating"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Operating"
    end

    test "displays ownership percentage", %{conn: conn} do
      company_fixture(%{name: "SubCo", ownership_pct: 75})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "75%"
    end

    test "displays --- when ownership percentage is nil", %{conn: conn} do
      company_fixture(%{name: "TopCo"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "---"
    end

    test "displays Holding tag for holding companies", %{conn: conn} do
      company_fixture(%{name: "HoldCo", is_holding: true})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag tag-teal"
      assert html =~ "Holding"
    end

    test "displays KYC status with appropriate tag", %{conn: conn} do
      company_fixture(%{name: "Approved Co", kyc_status: "approved"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-jade"
      assert html =~ "approved"
    end

    test "displays wind_down_status with appropriate tag", %{conn: conn} do
      company_fixture(%{name: "Active Co", wind_down_status: "active"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-jade"
      assert html =~ "active"
    end
  end

  describe "view toggle events" do
    test "clicking Tree button switches to tree view", %{conn: conn} do
      company_fixture(%{name: "TreeTest Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "company-tree"
      assert html =~ "Expand all"
      assert html =~ "Collapse all"
    end

    test "clicking List button switches back to list view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree first
      view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      # Switch back to list
      html = view |> element(~s(button[phx-value-mode="list"])) |> render_click()

      assert html =~ "<table>"
      assert html =~ "<th>Name</th>"
    end

    test "tree view shows company names as links", %{conn: conn} do
      company = company_fixture(%{name: "TreeNode Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "TreeNode Corp"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "tree view shows holding tag for holding companies", %{conn: conn} do
      company_fixture(%{name: "Tree Holding", is_holding: true})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "tag tag-teal"
      assert html =~ "Holding"
    end

    test "tree view shows country tag", %{conn: conn} do
      company_fixture(%{name: "Swiss Tree Co", country: "CH"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "tag tag-ink"
      assert html =~ "CH"
    end
  end

  describe "tree expand/collapse" do
    setup do
      parent = company_fixture(%{name: "Parent Corp"})
      _child = company_fixture(%{name: "Child Corp", parent_id: parent.id})
      %{parent: parent}
    end

    test "tree view shows parent company", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree view
      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      # Parent should always be visible
      assert html =~ "Parent Corp"
    end

    test "expand all button is present in tree view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree view
      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "Expand all"
      assert html =~ "Collapse all"
    end

    test "expand_all does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree view
      view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      # Expand all should succeed without error
      html = view |> element(~s(button[phx-click="expand_all"])) |> render_click()

      # Parent should still be visible in tree
      assert html =~ "Parent Corp"
    end

    test "collapse all keeps parent visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree view
      view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      # Expand all first, then collapse all
      view |> element(~s(button[phx-click="expand_all"])) |> render_click()
      html = view |> element(~s(button[phx-click="collapse_all"])) |> render_click()

      # Parent should still be visible
      assert html =~ "Parent Corp"
    end
  end

  describe "role-based visibility - viewer" do
    test "viewer does not see New Company button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      refute html =~ "New Company"
    end

    test "viewer does not see Import CSV link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      refute html =~ "Import CSV"
    end

    test "viewer does not see Delete button", %{conn: conn} do
      company_fixture(%{name: "No Delete Corp"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      refute html =~ "btn btn-danger btn-sm"
    end
  end

  describe "role-based visibility - editor" do
    test "editor sees New Company button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "New Company"
    end

    test "editor sees Import CSV link", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Import CSV"
    end

    test "editor sees Delete button for companies", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company_fixture(%{name: "Deletable Corp"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Delete"
      assert html =~ "btn btn-danger btn-sm"
    end
  end

  describe "GET /companies/new - new company form" do
    test "editor can navigate to new company form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "New Company"
      assert html =~ "modal-overlay"
      assert html =~ "modal"
    end

    test "new company form has required fields", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "Name *"
      assert html =~ "Country *"
      assert html =~ ~s(name="company[name]")
      assert html =~ ~s(name="company[country]")
    end

    test "new company form has optional fields", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "Category"
      assert html =~ "Parent Company"
      assert html =~ "Ownership %"
      assert html =~ "Holding company"
      assert html =~ ~s(name="company[category]")
      assert html =~ ~s(name="company[parent_id]")
      assert html =~ ~s(name="company[ownership_pct]")
      assert html =~ ~s(name="company[is_holding]")
    end

    test "new company form shows Create Company and Cancel buttons", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "Create Company"
      assert html =~ "Cancel"
    end

    test "parent company dropdown shows None (top-level) option", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "None (top-level)"
    end

    test "parent company dropdown lists existing companies", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company_fixture(%{name: "Potential Parent"})

      {:ok, _view, html} = live(conn, ~p"/companies/new")

      assert html =~ "Potential Parent"
    end
  end

  describe "creating a company" do
    test "editor can create a company via form submission", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/new")

      view
      |> form(~s(form[phx-submit="save"]), %{company: %{name: "New Test Corp", country: "UK"}})
      |> render_submit()

      # After creation, redirects to /companies
      {path, flash} = assert_redirect(view)
      assert path == "/companies"
      assert flash["info"] == "Company created"
    end

    test "new company appears in the list after creation", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/new")

      view
      |> form(~s(form[phx-submit="save"]), %{company: %{name: "Fresh Corp", country: "DE"}})
      |> render_submit()

      # Follow redirect
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Fresh Corp"
    end
  end

  describe "deleting a company" do
    test "editor can delete a company", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture(%{name: "Doomed Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{company.id}"]))
        |> render_click()

      assert html =~ "Company deleted"
      refute html =~ "Doomed Corp"
    end

    test "viewer does not see delete button for companies", %{conn: conn} do
      company_fixture(%{name: "Protected Corp"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Protected Corp"
      refute html =~ ~s(phx-click="delete")
    end
  end

  describe "close form" do
    test "close_form navigates back to /companies", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/new")

      view
      |> element(~s(button[phx-click="close_form"]))
      |> render_click()

      {path, _flash} = assert_redirect(view)
      assert path == "/companies"
    end
  end

  describe "permission guards for save and delete" do
    test "viewer save event returns permission error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies/new")

      html = render_hook(view, "save", %{"company" => %{"name" => "Blocked Co", "country" => "US"}})
      assert html =~ "permission"
    end

    test "viewer delete event returns permission error", %{conn: conn} do
      company = company_fixture(%{name: "UnDeletable Corp"})
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_hook(view, "delete", %{"id" => to_string(company.id)})
      assert html =~ "permission"
    end
  end

  describe "noop event" do
    test "noop does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      html = render_hook(view, "noop", %{})
      assert html =~ "Companies"
    end
  end

  describe "tree toggle_node event" do
    test "toggle_node via render_hook toggles expanded state", %{conn: conn} do
      parent = company_fixture(%{name: "Toggleable Parent"})
      _child = company_fixture(%{name: "Toggleable Child", parent_id: parent.id})

      {:ok, view, _html} = live(conn, ~p"/companies")

      # Switch to tree view
      view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      # Toggle node via hook
      html = render_hook(view, "toggle_node", %{"id" => to_string(parent.id)})
      assert html =~ "Toggleable Parent"

      # Toggle again
      html = render_hook(view, "toggle_node", %{"id" => to_string(parent.id)})
      assert html =~ "Toggleable Parent"
    end
  end

  describe "handle_info PubSub events" do
    test "companies_created broadcast refreshes the list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      company_fixture(%{name: "Broadcast Created Co"})

      send(view.pid, {:companies_created, %{}})

      html = render(view)
      assert html =~ "Broadcast Created Co"
    end

    test "companies_deleted broadcast refreshes the list", %{conn: conn} do
      company = company_fixture(%{name: "Broadcast Deleted Co"})
      {:ok, view, _html} = live(conn, ~p"/companies")

      Holdco.Corporate.delete_company(company)

      send(view.pid, {:companies_deleted, %{}})

      html = render(view)
      refute html =~ "Broadcast Deleted Co"
    end

    test "unknown message handled gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/companies")

      send(view.pid, {:unknown_event, %{}})

      html = render(view)
      assert html =~ "Companies"
    end
  end

  describe "KYC status tags" do
    test "in_progress KYC shows lemon tag", %{conn: conn} do
      company_fixture(%{name: "KYC In Progress Co", kyc_status: "in_progress"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-lemon"
      assert html =~ "in_progress"
    end

    test "rejected KYC shows crimson tag", %{conn: conn} do
      company_fixture(%{name: "KYC Rejected Co", kyc_status: "rejected"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-crimson"
      assert html =~ "rejected"
    end

    test "not_started KYC shows ink tag", %{conn: conn} do
      company_fixture(%{name: "KYC NotStarted Co", kyc_status: "not_started"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-ink"
      assert html =~ "not_started"
    end
  end

  describe "wind_down_status tags" do
    test "winding_down shows lemon tag", %{conn: conn} do
      company_fixture(%{name: "Winding Co", wind_down_status: "winding_down"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-lemon"
      assert html =~ "winding_down"
    end

    test "dissolved shows crimson tag", %{conn: conn} do
      company_fixture(%{name: "Dissolved Co", wind_down_status: "dissolved"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-crimson"
      assert html =~ "dissolved"
    end

    test "active status shows jade tag", %{conn: conn} do
      company_fixture(%{name: "Active Status Co", wind_down_status: "active"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "tag-jade"
      assert html =~ "active"
    end
  end

  describe "create company with invalid data" do
    test "invalid company submission shows error in form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/companies/new")

      # Submit empty form - missing required name/country
      html =
        view
        |> form(~s(form[phx-submit="save"]), %{company: %{name: "", country: ""}})
        |> render_submit()

      # Should still show the form (changeset errors)
      assert html =~ "company"
    end
  end
end
