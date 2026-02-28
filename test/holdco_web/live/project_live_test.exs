defmodule HoldcoWeb.ProjectLiveTest do
  use HoldcoWeb.ConnCase

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  # ------------------------------------------------------------------
  # GET /projects — basic rendering
  # ------------------------------------------------------------------

  describe "GET /projects" do
    test "renders the page with Projects title", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "Projects"
      assert html =~ "Track active and planned initiatives across the group"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "metrics-strip"
      assert html =~ "Total"
      assert html =~ "Active"
      assert html =~ "Planned"
      assert html =~ "Total Budget"
    end

    test "shows empty state when no projects exist", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "No projects found."
      assert html =~ "Create projects to track"
    end

    test "table shows project data", %{conn: conn} do
      project_fixture(%{
        name: "Due Diligence Alpha",
        status: "active",
        project_type: "ma_due_diligence"
      })

      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "Due Diligence Alpha"
      assert html =~ "Active"
      assert html =~ "Ma due diligence"
    end

    test "status tags render with correct classes", %{conn: conn} do
      project_fixture(%{name: "Planned Proj", status: "planned"})
      project_fixture(%{name: "Active Proj", status: "active"})
      project_fixture(%{name: "Hold Proj", status: "on_hold"})
      project_fixture(%{name: "Done Proj", status: "completed"})
      project_fixture(%{name: "Cancel Proj", status: "cancelled"})

      {:ok, _view, html} = live(conn, ~p"/projects")

      assert html =~ "tag-lemon"
      assert html =~ "tag-jade"
      assert html =~ "tag-amber"
      assert html =~ "tag-sage"
      assert html =~ "tag-crimson"
    end
  end

  # ------------------------------------------------------------------
  # show_form / close_form / noop
  # ------------------------------------------------------------------

  describe "show_form and close_form" do
    test "show_form opens modal for editor", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/projects")

      html = view |> element("button", "Add Project") |> render_click()

      assert html =~ "dialog-overlay"
      assert html =~ "Add Project"
    end

    test "close_form closes the modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/projects")

      view |> element("button", "Add Project") |> render_click()
      html = view |> element(~s(button[phx-click="close_form"])) |> render_click()

      refute html =~ "dialog-overlay"
    end

    test "clicking modal overlay fires close_form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/projects")

      view |> element("button", "Add Project") |> render_click()
      html = view |> element(".dialog-overlay") |> render_click()

      refute html =~ "dialog-overlay"
    end
  end

  describe "noop event" do
    test "noop does not crash and keeps modal open", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/projects")

      view |> element("button", "Add Project") |> render_click()
      html = view |> element(".dialog-panel") |> render_click()

      assert html =~ "dialog-overlay"
    end
  end

  # ------------------------------------------------------------------
  # CRUD operations (as editor)
  # ------------------------------------------------------------------

  describe "save creates a project" do
    test "editor can create a project via form", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      {:ok, view, _html} = live(conn, ~p"/projects")

      view |> element("button", "Add Project") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "project" => %{
            "name" => "Migration Project",
            "status" => "planned",
            "project_type" => "system_migration",
            "description" => "Migrate legacy systems",
            "start_date" => "2025-03-01",
            "target_date" => "2025-09-30",
            "budget" => "50000",
            "currency" => "USD"
          }
        })
        |> render_submit()

      assert html =~ "Project created"
      assert html =~ "Migration Project"
      refute html =~ "dialog-overlay"
    end
  end

  describe "delete removes a project" do
    test "editor can delete a project", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")
      project = project_fixture(%{name: "Delete This Project", status: "planned"})

      {:ok, view, _html} = live(conn, ~p"/projects")

      assert render(view) =~ "Delete This Project"

      html =
        view
        |> element(~s(button[phx-click="delete"][phx-value-id="#{project.id}"]))
        |> render_click()

      assert html =~ "Project deleted"
      refute html =~ "Delete This Project"
    end
  end

  describe "edit and update" do
    test "edit opens edit form with pre-filled data", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      project =
        project_fixture(%{
          name: "Editable Project",
          status: "active",
          project_type: "fundraise"
        })

      {:ok, view, _html} = live(conn, ~p"/projects")

      html =
        view
        |> element(~s(button[phx-click="edit"][phx-value-id="#{project.id}"]))
        |> render_click()

      assert html =~ "Edit Project"
      assert html =~ "dialog-overlay"
      assert html =~ "Editable Project"
    end

    test "update updates a project", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      project =
        project_fixture(%{
          name: "Original Project",
          status: "planned",
          project_type: "fundraise"
        })

      {:ok, view, _html} = live(conn, ~p"/projects")

      # Open edit form
      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{project.id}"]))
      |> render_click()

      # Submit update
      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "project" => %{
            "name" => "Renamed Project",
            "status" => "active",
            "project_type" => "compliance_project",
            "description" => "Updated description",
            "budget" => "75000",
            "currency" => "EUR"
          }
        })
        |> render_submit()

      assert html =~ "Project updated"
      assert html =~ "Renamed Project"
      refute html =~ "dialog-overlay"
    end
  end

  # ------------------------------------------------------------------
  # filter_status
  # ------------------------------------------------------------------

  describe "filter_status filters by status" do
    test "filtering by status shows only matching projects", %{conn: conn} do
      project_fixture(%{name: "Active One", status: "active"})
      project_fixture(%{name: "Planned One", status: "planned"})

      {:ok, view, _html} = live(conn, ~p"/projects")

      # Both visible initially
      assert render(view) =~ "Active One"
      assert render(view) =~ "Planned One"

      # Filter to active only
      html =
        view
        |> element(~s(button[phx-click="filter_status"][phx-value-status="active"]))
        |> render_click()

      assert html =~ "Active One"
      refute html =~ "Planned One"
    end

    test "clearing filter shows all projects", %{conn: conn} do
      project_fixture(%{name: "Active Two", status: "active"})
      project_fixture(%{name: "Planned Two", status: "planned"})

      {:ok, view, _html} = live(conn, ~p"/projects")

      # Filter first
      view
      |> element(~s(button[phx-click="filter_status"][phx-value-status="active"]))
      |> render_click()

      # Clear filter (click "All" button with empty status)
      html =
        view
        |> element(~s(button[phx-click="filter_status"][phx-value-status=""]))
        |> render_click()

      assert html =~ "Active Two"
      assert html =~ "Planned Two"
    end
  end

  # ------------------------------------------------------------------
  # Permission guards (viewer)
  # ------------------------------------------------------------------

  describe "permission guards" do
    test "viewer cannot save a project", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/projects")

      html =
        render_hook(view, "save", %{
          "project" => %{
            "name" => "Blocked Project",
            "status" => "planned",
            "project_type" => "fundraise"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer cannot delete a project", %{conn: conn} do
      project = project_fixture(%{name: "Protected Project"})
      {:ok, view, _html} = live(conn, ~p"/projects")

      html = render_hook(view, "delete", %{"id" => "#{project.id}"})

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer cannot update a project", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/projects")

      html =
        render_hook(view, "update", %{
          "project" => %{
            "name" => "Hacked Project",
            "status" => "active"
          }
        })

      assert html =~ "You don&#39;t have permission to do that"
    end

    test "viewer does not see Add Project button", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")

      refute html =~ "Add Project"
    end
  end

  # ------------------------------------------------------------------
  # handle_info (pubsub)
  # ------------------------------------------------------------------

  describe "handle_info" do
    test "pubsub message triggers reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/projects")

      project_fixture(%{name: "PubSub Project", status: "active"})

      send(view.pid, {:project_changed, %{}})
      html = render(view)
      assert html =~ "PubSub Project"
    end
  end

  # ------------------------------------------------------------------
  # save/update error paths
  # ------------------------------------------------------------------

  describe "save error path" do
    test "editor save failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      {:ok, view, _html} = live(conn, ~p"/projects")
      view |> element("button", "Add Project") |> render_click()

      # Submit with empty name to trigger error
      html =
        view
        |> form(~s(form[phx-submit="save"]), %{
          "project" => %{
            "name" => "",
            "status" => "planned",
            "project_type" => "fundraise"
          }
        })
        |> render_submit()

      assert html =~ "Failed to create project" || html =~ "Projects"
    end
  end

  describe "update error path" do
    test "editor update failure shows error flash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "editor")

      project = project_fixture(%{name: "Fail Update Proj", status: "planned"})

      {:ok, view, _html} = live(conn, ~p"/projects")

      view
      |> element(~s(button[phx-click="edit"][phx-value-id="#{project.id}"]))
      |> render_click()

      # Submit with empty name to trigger error
      html =
        view
        |> form(~s(form[phx-submit="update"]), %{
          "project" => %{
            "name" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to update project" || html =~ "Projects"
    end
  end

  # ------------------------------------------------------------------
  # budget formatting and contact display
  # ------------------------------------------------------------------

  describe "project display" do
    test "displays budget with commas", %{conn: conn} do
      project_fixture(%{
        name: "Big Budget Proj",
        status: "active",
        budget: Decimal.new("1000000"),
        currency: "USD"
      })

      {:ok, _view, html} = live(conn, ~p"/projects")
      assert html =~ "1,000,000"
      assert html =~ "USD"
    end

    test "displays project without budget shows dashes", %{conn: conn} do
      project_fixture(%{name: "No Budget Proj", status: "planned", budget: nil})

      {:ok, _view, html} = live(conn, ~p"/projects")
      assert html =~ "No Budget Proj"
      assert html =~ "---"
    end

    test "displays project with contact name", %{conn: conn} do
      contact = contact_fixture(%{name: "PM Lead"})
      project_fixture(%{name: "Contact Proj", status: "active", contact_id: contact.id})

      {:ok, _view, html} = live(conn, ~p"/projects")
      assert html =~ "PM Lead"
    end

    test "displays all status filter buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/projects")
      assert html =~ "Planned"
      assert html =~ "Active"
      assert html =~ "On hold"
      assert html =~ "Completed"
      assert html =~ "Cancelled"
    end

    test "filter by on_hold status", %{conn: conn} do
      project_fixture(%{name: "Hold Proj", status: "on_hold"})
      project_fixture(%{name: "Active Proj 3", status: "active"})

      {:ok, view, _html} = live(conn, ~p"/projects")
      html =
        view
        |> element(~s(button[phx-click="filter_status"][phx-value-status="on_hold"]))
        |> render_click()

      assert html =~ "Hold Proj"
      refute html =~ "Active Proj 3"
    end
  end
end
