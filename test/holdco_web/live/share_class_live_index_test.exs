defmodule HoldcoWeb.ShareClassLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Share Classes page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/share-classes")
      assert html =~ "Share Classes &amp; Cap Table"
      assert html =~ "Manage share classes and view capitalization table"
    end

    test "shows table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/share-classes")
      assert html =~ "All Share Classes"
      assert html =~ "Name"
      assert html =~ "Code"
      assert html =~ "Authorized"
      assert html =~ "Issued"
      assert html =~ "Outstanding"
      assert html =~ "Par Value"
    end

    test "shows empty state when no share classes exist", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/share-classes")
      assert html =~ "No share classes found."
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/share-classes")
      assert html =~ "All Companies"
    end

    test "displays an existing share class", %{conn: conn} do
      share_class_fixture(%{name: "Series A Preferred"})
      {:ok, _live, html} = live(conn, ~p"/share-classes")
      assert html =~ "Series A Preferred"
    end
  end

  describe "show_form and close_form" do
    test "show_form opens the new share class dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/share-classes")
      html = render_click(view, "show_form")
      assert html =~ "Add Share Class"
      assert html =~ "Name *"
      assert html =~ "Class Code *"
      assert html =~ "Company *"
    end

    test "close_form hides the dialog", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/share-classes")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "dialog-overlay"
    end
  end

  describe "filter_company" do
    test "filtering by company updates the list", %{conn: conn} do
      company = company_fixture(%{name: "Filter SC Corp"})
      share_class_fixture(%{company: company, name: "Filtered Class"})

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      html = render_change(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Filtered Class"
    end

    test "filtering with empty company_id shows all share classes", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/share-classes")
      html = render_change(view, "filter_company", %{"company_id" => ""})
      assert html =~ "All Share Classes"
    end
  end

  describe "save (create)" do
    test "creating a share class with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "share_class" => %{
            "company_id" => to_string(company.id),
            "name" => "Common Stock",
            "class_code" => "COM",
            "shares_authorized" => "100000",
            "shares_issued" => "50000",
            "shares_outstanding" => "45000",
            "par_value" => "0.01",
            "currency" => "USD",
            "voting_rights_per_share" => "1",
            "status" => "active"
          }
        })

      assert html =~ "Share class added"
      assert html =~ "Common Stock"
    end

    test "creating a share class with invalid data shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "share_class" => %{
            "name" => "",
            "class_code" => "",
            "company_id" => ""
          }
        })

      assert html =~ "Failed to add share class"
    end
  end

  describe "edit and update" do
    test "edit event opens edit form with existing data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      sc = share_class_fixture(%{name: "Editable Class", class_code: "EDT"})

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      html = render_click(view, "edit", %{"id" => to_string(sc.id)})
      assert html =~ "Edit Share Class"
      assert html =~ "Editable Class"
    end

    test "updating a share class with valid data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      company = company_fixture()
      sc = share_class_fixture(%{company: company, name: "Old Class Name", class_code: "OLD"})

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      render_click(view, "edit", %{"id" => to_string(sc.id)})

      html =
        render_click(view, "update", %{
          "share_class" => %{
            "company_id" => to_string(company.id),
            "name" => "Updated Class Name",
            "class_code" => "UPD",
            "shares_authorized" => "200000",
            "status" => "active"
          }
        })

      assert html =~ "Share class updated"
      assert html =~ "Updated Class Name"
    end
  end

  describe "delete" do
    test "deleting a share class removes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      sc = share_class_fixture(%{name: "Doomed Class", class_code: "DEL"})

      {:ok, view, _html} = live(conn, ~p"/share-classes")
      assert render(view) =~ "Doomed Class"

      html = render_click(view, "delete", %{"id" => to_string(sc.id)})
      assert html =~ "Share class deleted"
      refute html =~ "Doomed Class"
    end
  end

  describe "noop" do
    test "noop event does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/share-classes")
      html = render_click(view, "noop")
      assert html =~ "Share Classes"
    end
  end
end
