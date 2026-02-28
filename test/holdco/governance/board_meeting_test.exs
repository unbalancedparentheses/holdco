defmodule Holdco.Governance.BoardMeetingTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  # Helper to provide a default scheduled_date since the DB column is NOT NULL
  defp valid_meeting_attrs(company, overrides \\ %{}) do
    Map.merge(
      %{
        company_id: company.id,
        scheduled_date: "2026-04-01"
      },
      overrides
    )
  end

  describe "board meetings CRUD" do
    test "list_board_meetings/0 returns all board meetings" do
      bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-01]})
      assert Enum.any?(Governance.list_board_meetings(), &(&1.id == bm.id))
    end

    test "list_board_meetings/1 filters by company_id" do
      company = company_fixture()
      bm = board_meeting_fixture(%{company: company, meeting_date: ~D[2026-04-01]})
      other_bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-02]})

      results = Governance.list_board_meetings(company.id)
      assert Enum.any?(results, &(&1.id == bm.id))
      refute Enum.any?(results, &(&1.id == other_bm.id))
    end

    test "get_board_meeting!/1 returns the meeting with preloads" do
      bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-01]})
      fetched = Governance.get_board_meeting!(bm.id)
      assert fetched.id == bm.id
      assert fetched.company != nil
    end

    test "create_board_meeting/1 with valid data" do
      company = company_fixture()

      assert {:ok, bm} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{
                   title: "Q1 Review",
                   meeting_type: "regular",
                   meeting_date: ~D[2026-04-15],
                   start_time: ~T[09:00:00],
                   end_time: ~T[11:00:00],
                   location: "Board Room A",
                   is_virtual: false,
                   quorum_required: 5,
                   agenda: "Review financials\nApprove budget",
                   status: "scheduled"
                 })
               )

      assert bm.title == "Q1 Review"
      assert bm.meeting_type == "regular"
      assert bm.meeting_date == ~D[2026-04-15]
      assert bm.start_time == ~T[09:00:00]
      assert bm.end_time == ~T[11:00:00]
      assert bm.quorum_required == 5
      assert bm.is_virtual == false
    end

    test "create_board_meeting/1 with invalid meeting_type" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{meeting_type: "invalid_type"})
               )

      assert errors_on(cs)[:meeting_type]
    end

    test "create_board_meeting/1 with invalid status" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{status: "invalid_status"})
               )

      assert errors_on(cs)[:status]
    end

    test "create_board_meeting/1 without company_id fails" do
      assert {:error, cs} = Governance.create_board_meeting(%{title: "Test", scheduled_date: "2026-01-01"})
      assert errors_on(cs)[:company_id]
    end

    test "update_board_meeting/2 updates fields" do
      bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-01]})

      assert {:ok, updated} =
               Governance.update_board_meeting(bm, %{
                 title: "Updated Q1 Review",
                 status: "completed",
                 minutes: "Meeting minutes text",
                 attendees_count: 7
               })

      assert updated.title == "Updated Q1 Review"
      assert updated.status == "completed"
      assert updated.minutes == "Meeting minutes text"
      assert updated.attendees_count == 7
    end

    test "update_board_meeting/2 with invalid status fails" do
      bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-01]})
      assert {:error, cs} = Governance.update_board_meeting(bm, %{status: "bogus"})
      assert errors_on(cs)[:status]
    end

    test "delete_board_meeting/1 removes the meeting" do
      bm = board_meeting_fixture(%{meeting_date: ~D[2026-04-01]})
      assert {:ok, _} = Governance.delete_board_meeting(bm)
      assert_raise Ecto.NoResultsError, fn -> Governance.get_board_meeting!(bm.id) end
    end

    test "create_board_meeting/1 with virtual meeting" do
      company = company_fixture()

      assert {:ok, bm} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{
                   title: "Virtual Board Call",
                   meeting_type: "special",
                   is_virtual: true,
                   virtual_link: "https://zoom.us/meeting/123",
                   meeting_date: ~D[2026-05-01]
                 })
               )

      assert bm.is_virtual == true
      assert bm.virtual_link == "https://zoom.us/meeting/123"
    end

    test "create_board_meeting/1 with documents array" do
      company = company_fixture()

      assert {:ok, bm} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{
                   title: "Docs Meeting",
                   meeting_date: ~D[2026-05-01],
                   documents: ["report.pdf", "budget.xlsx"]
                 })
               )

      assert bm.documents == ["report.pdf", "budget.xlsx"]
    end

    test "create_board_meeting/1 with resolutions" do
      company = company_fixture()

      assert {:ok, bm} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{
                   title: "Resolutions Meeting",
                   meeting_date: ~D[2026-05-01],
                   resolutions: "Resolved: approve Q1 budget"
                 })
               )

      assert bm.resolutions == "Resolved: approve Q1 budget"
    end

    test "create_board_meeting/1 with negative quorum_required fails" do
      company = company_fixture()

      assert {:error, cs} =
               Governance.create_board_meeting(
                 valid_meeting_attrs(company, %{quorum_required: -1})
               )

      assert errors_on(cs)[:quorum_required]
    end
  end

  describe "upcoming_meetings/1" do
    test "returns future scheduled meetings" do
      company = company_fixture()
      future = Date.add(Date.utc_today(), 30)
      past = Date.add(Date.utc_today(), -30)

      {:ok, future_meeting} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{
            title: "Future Meeting",
            meeting_date: future,
            status: "scheduled"
          })
        )

      {:ok, _past_meeting} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{
            title: "Past Meeting",
            meeting_date: past,
            status: "scheduled"
          })
        )

      results = Governance.upcoming_meetings(company.id)
      assert Enum.any?(results, &(&1.id == future_meeting.id))
      refute Enum.any?(results, fn m -> m.title == "Past Meeting" end)
    end

    test "excludes cancelled meetings" do
      company = company_fixture()
      future = Date.add(Date.utc_today(), 30)

      {:ok, _cancelled} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{
            title: "Cancelled Meeting",
            meeting_date: future,
            status: "cancelled"
          })
        )

      results = Governance.upcoming_meetings(company.id)
      refute Enum.any?(results, fn m -> m.title == "Cancelled Meeting" end)
    end
  end

  describe "meeting_calendar/2" do
    test "returns meetings within date range" do
      company = company_fixture()

      {:ok, m1} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{
            title: "March Meeting",
            meeting_date: ~D[2026-03-15]
          })
        )

      {:ok, _m2} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{
            title: "April Meeting",
            meeting_date: ~D[2026-04-15]
          })
        )

      range = Date.range(~D[2026-03-01], ~D[2026-03-31])
      results = Governance.meeting_calendar(company.id, range)
      assert Enum.any?(results, &(&1.id == m1.id))
      refute Enum.any?(results, fn m -> m.title == "April Meeting" end)
    end
  end

  describe "board meeting subscribe" do
    test "PubSub broadcast on create" do
      Governance.subscribe()
      company = company_fixture()

      {:ok, _bm} =
        Governance.create_board_meeting(
          valid_meeting_attrs(company, %{title: "Broadcast Test"})
        )

      assert_receive {:board_meetings_created, _}
    end
  end
end
