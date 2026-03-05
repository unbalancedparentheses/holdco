defmodule HoldcoWeb.OrgChartLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "shows parent-child relationships", %{conn: conn} do
      parent = company_fixture(%{name: "Holding Co"})
      company_fixture(%{name: "Sub Corp", parent_id: parent.id})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Holding Co"
      assert html =~ "Sub Corp"
    end

    test "renders company with ownership_pct", %{conn: conn} do
      parent = company_fixture(%{name: "Parent Corp"})
      company_fixture(%{name: "Owned Sub", parent_id: parent.id, ownership_pct: 75})

      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Owned Sub"
      assert html =~ "75%"
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

    test "editor sees Add Company link on empty state", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, _live, html} = live(conn, ~p"/org-chart")
      assert html =~ "Add Company"
    end

  end
end
