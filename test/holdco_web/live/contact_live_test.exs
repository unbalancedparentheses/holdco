defmodule HoldcoWeb.ContactLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ------------------------------------------------------------------
  # GET /contacts — basic rendering
  # ------------------------------------------------------------------

  describe "GET /contacts" do
    test "renders the page with Contacts title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contacts")

      assert html =~ "Contacts"
      assert html =~ "Key people across the holding structure"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contacts")

      assert html =~ "metrics-strip"
      assert html =~ "Total Contacts"
      assert html =~ "Organizations"
      assert html =~ "Role Tags"
    end

    test "shows empty state when no contacts exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contacts")

      assert html =~ "No contacts found."
      assert html =~ "Add lawyers, accountants, bankers"
    end

    test "table shows contact data", %{conn: conn} do
      contact_fixture(%{
        name: "Jane Doe",
        organization: "Acme Legal",
        email: "jane@acmelegal.com",
        role_tag: "lawyer"
      })

      {:ok, _view, html} = live(conn, ~p"/contacts")

      assert html =~ "Jane Doe"
      assert html =~ "Acme Legal"
      assert html =~ "jane@acmelegal.com"
      assert html =~ "lawyer"
    end
  end

  # ------------------------------------------------------------------
  # show_form / close_form / noop
  # ------------------------------------------------------------------

  describe "show_form and close_form" do
    test "show_form opens modal for editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      html = view |> element("button", "Add Contact") |> render_click()

      assert html =~ "modal-overlay"
      assert html =~ "Add Contact"
    end

    test "close_form closes the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "modal-overlay"
    end

    test "clicking modal overlay fires close_form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element(".modal-overlay") |> render_click()

      refute html =~ "modal-overlay"
    end
  end

  describe "noop event" do
    test "noop does not crash and keeps modal open", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element(".modal") |> render_click()

      assert html =~ "modal-overlay"
    end
  end

  # ------------------------------------------------------------------
  # CRUD operations (as editor)
  # ------------------------------------------------------------------

  describe "save creates a contact" do
    test "editor can create a contact via form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "contact" => %{
            "name" => "Bob Smith",
            "title" => "Partner",
            "organization" => "Smith & Co",
            "email" => "bob@smithco.com",
            "phone" => "+1-555-1234",
            "role_tag" => "lawyer"
          }
        })
        |> render_submit()

      assert html =~ "Contact created"
      assert html =~ "Bob Smith"
      assert html =~ "Smith &amp; Co"
      assert html =~ "bob@smithco.com"
      refute html =~ "modal-overlay"
    end
  end

  describe "delete removes a contact" do
    test "editor can delete a contact", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Delete Me", organization: "DelOrg"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      assert render(view) =~ "Delete Me"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "Contact deleted"
      refute html =~ "Delete Me"
    end
  end

  describe "edit and update" do
    test "edit opens edit form with pre-filled data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      contact =
        contact_fixture(%{
          name: "Editable Contact",
          organization: "EditOrg",
          email: "edit@editorg.com",
          role_tag: "accountant"
        })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "Edit Contact"
      assert html =~ "modal-overlay"
      assert html =~ "Editable Contact"
      assert html =~ "EditOrg"
      assert html =~ "edit@editorg.com"
    end

    test "update updates a contact", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      contact =
        contact_fixture(%{
          name: "Original Name",
          organization: "OrigOrg",
          role_tag: "banker"
        })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      # Open edit form
      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{contact.id}"]))
      |> render_click()

      # Submit update
      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "contact" => %{
            "name" => "Updated Name",
            "title" => "Senior Partner",
            "organization" => "NewOrg",
            "email" => "updated@neworg.com",
            "phone" => "+1-555-9999",
            "role_tag" => "advisor"
          }
        })
        |> render_submit()

      assert html =~ "Contact updated"
      assert html =~ "Updated Name"
      assert html =~ "NewOrg"
      refute html =~ "modal-overlay"
    end
  end

  # ------------------------------------------------------------------
  # Search
  # ------------------------------------------------------------------

  describe "search filters contacts" do
    test "search filters contacts by name", %{conn: conn} do
      contact_fixture(%{name: "Alpha Person", organization: "AlphaCo"})
      contact_fixture(%{name: "Beta Person", organization: "BetaCo"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      # Both visible initially
      assert render(view) =~ "Alpha Person"
      assert render(view) =~ "Beta Person"

      # Search for Alpha
      html = view |> form(~s(form[phx-change="search"]), %{"q" => "Alpha"}) |> render_change()

      assert html =~ "Alpha Person"
      refute html =~ "Beta Person"
    end

    test "clearing search shows all contacts", %{conn: conn} do
      contact_fixture(%{name: "Gamma Person"})
      contact_fixture(%{name: "Delta Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      # Filter first
      view |> form(~s(form[phx-change="search"]), %{"q" => "Gamma"}) |> render_change()

      # Clear search
      html = view |> form(~s(form[phx-change="search"]), %{"q" => ""}) |> render_change()

      assert html =~ "Gamma Person"
      assert html =~ "Delta Person"
    end
  end

  # ------------------------------------------------------------------
  # Permission guards (viewer)
  # ------------------------------------------------------------------

  describe "permission guards" do
    test "viewer cannot save a contact", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        render_hook(view, "save", %{
          "contact" => %{
            "name" => "Blocked Contact",
            "title" => "CEO",
            "organization" => "BlockedOrg",
            "email" => "blocked@org.com",
            "phone" => "+1-555-0000",
            "role_tag" => "advisor"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer cannot delete a contact", %{conn: conn} do
      contact = contact_fixture(%{name: "Protected Contact"})
      {:ok, view, _html} = live(conn, ~p"/contacts")

      html = render_hook(view, "delete", %{"id" => "#{contact.id}"})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer cannot update a contact", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        render_hook(view, "update", %{
          "contact" => %{
            "name" => "Hacked Name",
            "organization" => "HackedOrg"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer does not see Add Contact button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/contacts")

      refute html =~ "Add Contact"
    end
  end
end
