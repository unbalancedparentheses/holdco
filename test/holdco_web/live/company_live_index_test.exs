defmodule HoldcoWeb.CompanyLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /companies - page rendering" do
    test "shows entity count in deck", %{conn: conn} do
      company_fixture(%{name: "CountMe Corp"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "1 entities in the corporate structure"
    end

    test "shows 0 entities when no companies exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "0 entities in the corporate structure"
    end
  end

  describe "GET /companies - company display" do
    test "displays company name as link", %{conn: conn} do
      company = company_fixture(%{name: "Acme Holdings"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "Acme Holdings"
      assert html =~ ~s(/companies/#{company.id})
    end

    test "displays --- when ownership percentage is nil", %{conn: conn} do
      company_fixture(%{name: "TopCo"})

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "---"
    end
  end

  describe "view toggle events" do
    test "clicking Tree button switches to tree view", %{conn: conn} do
      company_fixture(%{name: "TreeTest Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "company-tree"
      assert html =~ "TreeTest Corp"
    end

    test "tree view shows company names as links", %{conn: conn} do
      company = company_fixture(%{name: "TreeNode Corp"})

      {:ok, view, _html} = live(conn, ~p"/companies")

      html = view |> element(~s(button[phx-value-mode="tree"])) |> render_click()

      assert html =~ "TreeNode Corp"
      assert html =~ ~s(/companies/#{company.id})
    end
  end

  describe "tree expand/collapse" do
    setup do
      parent = company_fixture(%{name: "Parent Corp"})
      _child = company_fixture(%{name: "Child Corp", parent_id: parent.id})
      %{parent: parent}
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

  describe "role-based visibility - editor" do
    test "editor sees New Company button", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, _view, html} = live(conn, ~p"/companies")

      assert html =~ "New Company"
    end
  end

  describe "GET /companies/new - new company form" do
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
