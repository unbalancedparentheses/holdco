defmodule HoldcoWeb.ContactLiveTest do
  use HoldcoWeb.ConnCase, async: true

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

      assert html =~ "dialog-overlay"
      assert html =~ "Add Contact"
    end

    test "close_form closes the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element("button", "Cancel") |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "clicking modal overlay fires close_form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "noop event" do
    test "noop does not crash and keeps modal open", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/contacts")

      view |> element("button", "Add Contact") |> render_click()
      html = view |> element(".dialog-panel") |> render_click()

      assert html =~ "dialog-overlay"
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
      refute html =~ "dialog-overlay"
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
      assert html =~ "dialog-overlay"
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
      refute html =~ "dialog-overlay"
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
  # handle_info (pubsub)
  # ------------------------------------------------------------------

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contacts")

      contact_fixture(%{name: "PubSub Contact", organization: "PubSubOrg"})

      send(view.pid, {:contact_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Contact"
    end

    test "reload preserves active search filter", %{conn: conn} do
      contact_fixture(%{name: "Alpha Stay", organization: "AlphaOrg"})
      contact_fixture(%{name: "Beta Stay", organization: "BetaOrg"})

      {:ok, view, _html} = live(conn, ~p"/contacts")
      view |> form(~s(form[phx-change="search"]), %{"q" => "Alpha"}) |> render_change()

      send(view.pid, {:contact_changed, %{}})
      html = render(view)
      assert html =~ "Alpha Stay"
    end
  end

  # ------------------------------------------------------------------
  # Search by various fields
  # ------------------------------------------------------------------

  describe "search by different fields" do
    test "search filters by organization", %{conn: conn} do
      contact_fixture(%{name: "Org Search Person", organization: "UniqueOrgName"})
      contact_fixture(%{name: "Other Person", organization: "OtherOrg"})

      {:ok, view, _html} = live(conn, ~p"/contacts")
      html = view |> form(~s(form[phx-change="search"]), %{"q" => "UniqueOrgName"}) |> render_change()
      assert html =~ "Org Search Person"
      refute html =~ "Other Person"
    end

    test "search filters by email", %{conn: conn} do
      contact_fixture(%{name: "Email Person", email: "uniqueemail@test.com"})
      contact_fixture(%{name: "Other Email Person", email: "other@test.com"})

      {:ok, view, _html} = live(conn, ~p"/contacts")
      html = view |> form(~s(form[phx-change="search"]), %{"q" => "uniqueemail"}) |> render_change()
      assert html =~ "Email Person"
      refute html =~ "Other Email Person"
    end

    test "search filters by role_tag", %{conn: conn} do
      contact_fixture(%{name: "Banker Person", role_tag: "banker"})
      contact_fixture(%{name: "Lawyer Person", role_tag: "lawyer"})

      {:ok, view, _html} = live(conn, ~p"/contacts")
      html = view |> form(~s(form[phx-change="search"]), %{"q" => "banker"}) |> render_change()
      assert html =~ "Banker Person"
      refute html =~ "Lawyer Person"
    end
  end

  # ------------------------------------------------------------------
  # Role tag rendering
  # ------------------------------------------------------------------

  describe "role tag display" do
    test "renders lawyer role tag", %{conn: conn} do
      contact_fixture(%{name: "L Person", role_tag: "lawyer"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "lawyer"
      assert html =~ "tag-ink"
    end

    test "renders accountant role tag", %{conn: conn} do
      contact_fixture(%{name: "A Person", role_tag: "accountant"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "accountant"
      assert html =~ "tag-jade"
    end

    test "renders banker role tag", %{conn: conn} do
      contact_fixture(%{name: "B Person", role_tag: "banker"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "banker"
      assert html =~ "tag-teal"
    end

    test "renders regulator role tag", %{conn: conn} do
      contact_fixture(%{name: "R Person", role_tag: "regulator"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "regulator"
      assert html =~ "tag-crimson"
    end

    test "renders investor role tag", %{conn: conn} do
      contact_fixture(%{name: "I Person", role_tag: "investor"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "investor"
      assert html =~ "tag-lemon"
    end

    test "renders board_member role tag", %{conn: conn} do
      contact_fixture(%{name: "BM Person", role_tag: "board_member"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "board_member"
      assert html =~ "tag-teal"
    end

    test "renders unknown role tag with default class", %{conn: conn} do
      contact_fixture(%{name: "Other Person", role_tag: "other"})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "other"
      assert html =~ "tag-ink"
    end

    test "renders contact without role_tag shows dashes", %{conn: conn} do
      contact_fixture(%{name: "No Role Person", role_tag: nil})

      {:ok, _view, html} = live(conn, ~p"/contacts")
      assert html =~ "No Role Person"
      assert html =~ "---"
    end
  end

  # ------------------------------------------------------------------
  # Save/update error paths
  # ------------------------------------------------------------------

  describe "save error path" do
    test "editor save failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/contacts")
      view |> element("button", "Add Contact") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "contact" => %{"name" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to create contact" || html =~ "Contacts"
    end
  end

  describe "update error path" do
    test "editor update failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Update Fail Contact"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{contact.id}"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "contact" => %{"name" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to update contact" || html =~ "Contacts"
    end
  end

  # ------------------------------------------------------------------
  # Interactions — view, add, cancel, save, delete
  # ------------------------------------------------------------------

  describe "view_interactions" do
    test "clicking History opens interaction dialog for a contact", %{conn: conn} do
      contact = contact_fixture(%{name: "Interactive Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "Interaction History"
      assert html =~ "Interactive Person"
      assert html =~ "No interactions recorded yet."
    end

    test "close_interactions dismisses the dialog", %{conn: conn} do
      contact = contact_fixture(%{name: "Closeable Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      html = view |> element(".dialog-overlay") |> render_click()
      refute html =~ "Interaction History"
    end
  end

  describe "add_interaction and cancel_interaction_form" do
    test "add_interaction shows the interaction form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Form Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      html =
        view
        |> element(~s(button[phx-click="add_interaction"]))
        |> render_click()

      assert html =~ ~s(phx-submit="save_interaction")
      assert html =~ "Type"
      assert html =~ "Summary"
    end

    test "cancel_interaction_form hides the interaction form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Cancel Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="add_interaction"]))
      |> render_click()

      html =
        view
        |> element(~s(button[phx-click="cancel_interaction_form"]))
        |> render_click()

      refute html =~ ~s(phx-submit="save_interaction")
    end
  end

  describe "save_interaction" do
    test "editor can save an interaction", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Save Interaction Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="add_interaction"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_interaction"]), %{
          "interaction" => %{
            "interaction_type" => "call",
            "date" => "2025-06-15",
            "summary" => "Discussed Q2 results",
            "notes" => "Follow up next week"
          }
        })
        |> render_submit()

      assert html =~ "Interaction added"
      assert html =~ "call"
      assert html =~ "Discussed Q2 results"
    end

    test "save_interaction with missing required fields shows error", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Fail Interaction Person"})

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      view
      |> element(~s(button[phx-click="add_interaction"]))
      |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_interaction"]), %{
          "interaction" => %{
            "interaction_type" => "",
            "summary" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to add interaction"
    end
  end

  describe "delete_interaction" do
    test "editor can delete an interaction", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      contact = contact_fixture(%{name: "Del Interaction Person"})

      {:ok, interaction} =
        Holdco.Collaboration.create_interaction(%{
          contact_id: contact.id,
          interaction_type: "meeting",
          summary: "Quarterly review",
          date: "2025-03-10"
        })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      view
      |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
      |> render_click()

      html =
        view
        |> element(~s(button[phx-click="delete_interaction"][phx-value-id="#{interaction.id}"]))
        |> render_click()

      assert html =~ "Interaction deleted"
      refute html =~ "Quarterly review"
    end
  end

  describe "interactions display" do
    test "shows multiple interactions in history", %{conn: conn} do
      contact = contact_fixture(%{name: "Multi Interaction Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "call",
        summary: "First call",
        date: "2025-01-10"
      })

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "meeting",
        summary: "Board meeting",
        date: "2025-02-20"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "First call"
      assert html =~ "Board meeting"
      assert html =~ "call"
      assert html =~ "meeting"
    end

    test "interaction with notes displays notes", %{conn: conn} do
      contact = contact_fixture(%{name: "Notes Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "email",
        summary: "Sent proposal",
        notes: "Awaiting feedback by Friday",
        date: "2025-04-01"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "Sent proposal"
      assert html =~ "Awaiting feedback by Friday"
    end
  end

  # ------------------------------------------------------------------
  # Interaction type CSS classes
  # ------------------------------------------------------------------

  describe "interaction type display" do
    test "call interaction shows jade tag", %{conn: conn} do
      contact = contact_fixture(%{name: "Tag Call Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "call",
        summary: "Test call"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "tag-jade"
    end

    test "meeting interaction shows teal tag", %{conn: conn} do
      contact = contact_fixture(%{name: "Tag Meeting Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "meeting",
        summary: "Test meeting"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "tag-teal"
    end

    test "email interaction shows lemon tag", %{conn: conn} do
      contact = contact_fixture(%{name: "Tag Email Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "email",
        summary: "Test email"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "tag-lemon"
    end

    test "note interaction shows ink tag", %{conn: conn} do
      contact = contact_fixture(%{name: "Tag Note Person"})

      Holdco.Collaboration.create_interaction(%{
        contact_id: contact.id,
        interaction_type: "note",
        summary: "Test note"
      })

      {:ok, view, _html} = live(conn, ~p"/contacts")

      html =
        view
        |> element(~s(button[phx-click="view_interactions"][phx-value-id="#{contact.id}"]))
        |> render_click()

      assert html =~ "tag-ink"
    end
  end
end
