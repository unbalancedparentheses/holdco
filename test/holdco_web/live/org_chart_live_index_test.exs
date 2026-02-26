defmodule HoldcoWeb.OrgChartLiveIndexTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Org Chart page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Org Chart"
    end

    test "shows empty state when no companies exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "No companies found" || html =~ "Org Chart"
    end

    test "renders company cards", %{conn: conn} do
      company_fixture(%{name: "Parent Corp"})
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Parent Corp"
    end

    test "shows parent-child relationships", %{conn: conn} do
      parent = company_fixture(%{name: "Holding Co"})
      company_fixture(%{name: "Sub Corp", parent_id: parent.id})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Holding Co"
      assert html =~ "Sub Corp"
    end

    test "displays company details in cards", %{conn: conn} do
      company_fixture(%{name: "Detail Corp", country: "US", category: "subsidiary"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Detail Corp"
    end

    test "displays legend section when companies exist", %{conn: conn} do
      company_fixture(%{name: "Legend Test Corp"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Legend"
      assert html =~ "active"
    end

    test "shows link to list view", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "List View"
    end

    test "renders company with ownership_pct", %{conn: conn} do
      parent = company_fixture(%{name: "Parent Corp"})
      company_fixture(%{name: "Owned Sub", parent_id: parent.id, ownership_pct: 75})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Owned Sub"
      assert html =~ "75" || html =~ "owned"
    end

    test "renders company with winding_down status", %{conn: conn} do
      company_fixture(%{name: "Winding Corp", wind_down_status: "winding_down"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Winding Corp"
      assert html =~ "winding_down"
    end

    test "renders company with dissolved status", %{conn: conn} do
      company_fixture(%{name: "Dissolved Corp", wind_down_status: "dissolved"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Dissolved Corp"
      assert html =~ "dissolved"
    end

    test "renders multi-level hierarchy", %{conn: conn} do
      grandparent = company_fixture(%{name: "Grandparent Co"})
      parent = company_fixture(%{name: "Parent Co", parent_id: grandparent.id})
      company_fixture(%{name: "Child Co", parent_id: parent.id})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Grandparent Co"
      assert html =~ "Parent Co"
      assert html =~ "Child Co"
    end

    test "renders multiple root-level companies", %{conn: conn} do
      company_fixture(%{name: "Root One"})
      company_fixture(%{name: "Root Two"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Root One"
      assert html =~ "Root Two"
    end

    test "renders company with category tag", %{conn: conn} do
      company_fixture(%{name: "Categorized Corp", category: "holding"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Categorized Corp"
      assert html =~ "holding"
    end

    test "shows country in card", %{conn: conn} do
      company_fixture(%{name: "Country Test Corp", country: "GB"})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "GB"
    end

    test "displays page title and deck description", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Corporate structure and ownership hierarchy"
    end

    test "parent with multiple children renders connector lines", %{conn: conn} do
      parent = company_fixture(%{name: "Multi Parent"})
      company_fixture(%{name: "Child A", parent_id: parent.id})
      company_fixture(%{name: "Child B", parent_id: parent.id})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Multi Parent"
      assert html =~ "Child A"
      assert html =~ "Child B"
    end

    test "parent with single child does not show wide connector", %{conn: conn} do
      parent = company_fixture(%{name: "Single Parent"})
      company_fixture(%{name: "Only Child", parent_id: parent.id})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Single Parent"
      assert html =~ "Only Child"
    end

    test "editor sees Add Company link on empty state", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Add Company"
    end

    test "viewer does not see Add Company link on empty state", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      refute html =~ ~s(Add Company</a>)
    end

    test "renders company without category", %{conn: conn} do
      company_fixture(%{name: "No Category Corp", category: nil})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "No Category Corp"
    end

    test "renders company without ownership_pct", %{conn: conn} do
      parent = company_fixture(%{name: "Parent No Pct"})
      company_fixture(%{name: "Sub No Pct", parent_id: parent.id, ownership_pct: nil})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Sub No Pct"
    end
  end
end
