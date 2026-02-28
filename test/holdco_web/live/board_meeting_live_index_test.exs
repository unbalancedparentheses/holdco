defmodule HoldcoWeb.BoardMeetingLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Board Meetings page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/board-meetings")
      assert html =~ "Board Meetings"
    end

    test "shows meetings table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/board-meetings")
      assert html =~ "Title"
      assert html =~ "Type"
      assert html =~ "Date"
      assert html =~ "Location"
      assert html =~ "Status"
    end

    test "shows empty state when no meetings", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/board-meetings")
      assert html =~ "No board meetings yet"
    end

    test "shows view toggle and new meeting button", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/board-meetings")
      assert html =~ "Calendar View"
      assert html =~ "New Meeting"
    end

    test "shows company filter", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/board-meetings")
      assert html =~ "All Companies"
    end

    test "opens new meeting form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/board-meetings")
      html = render_click(live, "show_form")
      assert html =~ "New Board Meeting"
      assert html =~ "Create Meeting"
    end

    test "switches to calendar view", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/board-meetings")
      html = render_click(live, "switch_view", %{"mode" => "calendar"})
      assert html =~ "Sun"
      assert html =~ "Mon"
      assert html =~ "Tue"
    end
  end

  describe "close_form" do
    test "closes the new meeting form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "New Board Meeting"
    end
  end

  describe "save (create board meeting)" do
    test "creates a board meeting with valid data", %{conn: conn} do
      company = company_fixture(%{name: "Meeting Corp"})

      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "board_meeting" => %{
            "company_id" => to_string(company.id),
            "title" => "Q1 Board Review",
            "meeting_type" => "regular",
            "scheduled_date" => "2025-03-15",
            "meeting_date" => "2025-03-15",
            "location" => "Main Office",
            "is_virtual" => "false"
          }
        })

      assert html =~ "Board meeting created" or html =~ "Q1 Board Review"
    end

    test "shows error when creating with missing company", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "board_meeting" => %{
            "title" => "Bad Meeting",
            "meeting_type" => "regular"
          }
        })

      assert html =~ "Failed to create board meeting"
    end
  end

  describe "edit" do
    test "opens edit form for an existing meeting", %{conn: conn} do
      company = company_fixture()
      meeting = board_meeting_fixture(%{company: company, title: "Editable Meeting"})

      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      html = render_click(view, "edit", %{"id" => to_string(meeting.id)})

      assert html =~ "Edit Board Meeting"
      assert html =~ "Update Meeting"
    end
  end

  describe "update" do
    test "updates a board meeting", %{conn: conn} do
      company = company_fixture()
      meeting = board_meeting_fixture(%{company: company, title: "Old Title"})

      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "edit", %{"id" => to_string(meeting.id)})

      html =
        render_click(view, "update", %{
          "board_meeting" => %{
            "company_id" => to_string(company.id),
            "title" => "Updated Board Title",
            "meeting_type" => "special",
            "status" => "completed"
          }
        })

      assert html =~ "Board meeting updated"
      assert html =~ "Updated Board Title"
    end
  end

  describe "delete" do
    test "deletes a board meeting", %{conn: conn} do
      company = company_fixture()
      meeting = board_meeting_fixture(%{company: company, title: "Delete Me Meeting"})

      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      assert render(view) =~ "Delete Me Meeting"

      html = render_click(view, "delete", %{"id" => to_string(meeting.id)})
      assert html =~ "Board meeting deleted"
      refute html =~ "Delete Me Meeting"
    end
  end

  describe "filter_company" do
    test "filters meetings by company", %{conn: conn} do
      company = company_fixture(%{name: "Filter Corp"})
      board_meeting_fixture(%{company: company, title: "Filtered Meeting"})

      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      html = render_click(view, "filter_company", %{"company_id" => to_string(company.id)})
      assert html =~ "Filtered Meeting"
    end

    test "clears company filter with empty string", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      html = render_click(view, "filter_company", %{"company_id" => ""})
      assert html =~ "Board Meetings"
    end
  end

  describe "calendar navigation" do
    test "navigates to previous month", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "switch_view", %{"mode" => "calendar"})
      html = render_click(view, "prev_month")
      assert html =~ "Sun"
    end

    test "navigates to next month", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")
      render_click(view, "switch_view", %{"mode" => "calendar"})
      html = render_click(view, "next_month")
      assert html =~ "Sun"
    end
  end

  describe "switch_view" do
    test "switches from list to calendar and back", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/board-meetings")

      html = render_click(view, "switch_view", %{"mode" => "calendar"})
      assert html =~ "List View"
      assert html =~ "Sun"

      html = render_click(view, "switch_view", %{"mode" => "list"})
      assert html =~ "Calendar View"
    end
  end

  describe "displays existing data" do
    test "shows meeting in list view", %{conn: conn} do
      company = company_fixture(%{name: "Board Corp"})
      board_meeting_fixture(%{company: company, title: "Annual Meeting 2025", meeting_type: "annual"})

      {:ok, _view, html} = live(conn, ~p"/board-meetings")
      assert html =~ "Annual Meeting 2025"
      assert html =~ "annual"
    end
  end
end
