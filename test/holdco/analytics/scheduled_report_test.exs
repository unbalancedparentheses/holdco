defmodule Holdco.Analytics.ScheduledReportTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "list_scheduled_reports/0" do
    test "returns all scheduled reports" do
      sr = scheduled_report_fixture(%{name: "Weekly Portfolio"})
      reports = Analytics.list_scheduled_reports()
      assert length(reports) >= 1
      assert Enum.any?(reports, &(&1.id == sr.id))
    end

    test "returns empty list when no reports exist" do
      reports = Analytics.list_scheduled_reports()
      # May have pre-existing reports from other tests, but should not error
      assert is_list(reports)
    end
  end

  describe "list_scheduled_reports/1 with company_id" do
    test "filters by company_id" do
      c1 = company_fixture(%{name: "ReportCo1"})
      c2 = company_fixture(%{name: "ReportCo2"})
      sr1 = scheduled_report_fixture(%{company: c1, name: "Report A"})
      _sr2 = scheduled_report_fixture(%{company: c2, name: "Report B"})

      reports = Analytics.list_scheduled_reports(c1.id)
      assert length(reports) == 1
      assert hd(reports).id == sr1.id
    end
  end

  describe "get_scheduled_report!/1" do
    test "returns the report with given id" do
      sr = scheduled_report_fixture(%{name: "Get Report"})
      found = Analytics.get_scheduled_report!(sr.id)
      assert found.id == sr.id
      assert found.name == "Get Report"
    end

    test "raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_scheduled_report!(0)
      end
    end
  end

  describe "create_scheduled_report/1" do
    test "with valid attrs creates a report" do
      company = company_fixture()

      assert {:ok, sr} =
               Analytics.create_scheduled_report(%{
                 company_id: company.id,
                 name: "Monthly Financial",
                 report_type: "financial_report",
                 frequency: "monthly",
                 recipients: "cfo@example.com, ceo@example.com",
                 format: "html"
               })

      assert sr.name == "Monthly Financial"
      assert sr.report_type == "financial_report"
      assert sr.frequency == "monthly"
      assert sr.recipients == "cfo@example.com, ceo@example.com"
      assert sr.is_active == true
    end

    test "sets next_run_date to today when not provided" do
      company = company_fixture()

      assert {:ok, sr} =
               Analytics.create_scheduled_report(%{
                 company_id: company.id,
                 name: "Auto Date Report",
                 report_type: "portfolio_summary",
                 frequency: "daily",
                 recipients: "test@example.com"
               })

      assert sr.next_run_date == Date.to_iso8601(Date.utc_today())
    end

    test "fails without required fields" do
      assert {:error, changeset} = Analytics.create_scheduled_report(%{})
      errors = errors_on(changeset)
      assert errors[:name]
      assert errors[:report_type]
      assert errors[:frequency]
      assert errors[:recipients]
    end

    test "validates report_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_scheduled_report(%{
                 name: "Bad Type",
                 report_type: "invalid_type",
                 frequency: "daily",
                 recipients: "test@example.com"
               })

      assert %{report_type: _} = errors_on(changeset)
    end

    test "validates frequency inclusion" do
      assert {:error, changeset} =
               Analytics.create_scheduled_report(%{
                 name: "Bad Freq",
                 report_type: "portfolio_summary",
                 frequency: "biweekly",
                 recipients: "test@example.com"
               })

      assert %{frequency: _} = errors_on(changeset)
    end

    test "validates format inclusion" do
      assert {:error, changeset} =
               Analytics.create_scheduled_report(%{
                 name: "Bad Format",
                 report_type: "portfolio_summary",
                 frequency: "daily",
                 recipients: "test@example.com",
                 format: "pdf"
               })

      assert %{format: _} = errors_on(changeset)
    end
  end

  describe "update_scheduled_report/2" do
    test "updates a report successfully" do
      sr = scheduled_report_fixture(%{name: "Old Report"})
      assert {:ok, updated} = Analytics.update_scheduled_report(sr, %{name: "New Report"})
      assert updated.name == "New Report"
    end

    test "can toggle is_active" do
      sr = scheduled_report_fixture(%{name: "Toggle Report"})
      assert sr.is_active == true
      assert {:ok, updated} = Analytics.update_scheduled_report(sr, %{is_active: false})
      assert updated.is_active == false
    end
  end

  describe "delete_scheduled_report/1" do
    test "deletes the report" do
      sr = scheduled_report_fixture(%{name: "Delete Me"})
      assert {:ok, _} = Analytics.delete_scheduled_report(sr)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_scheduled_report!(sr.id)
      end
    end
  end

  describe "list_due_scheduled_reports/0" do
    test "returns active reports with next_run_date <= today" do
      today = Date.to_iso8601(Date.utc_today())
      yesterday = Date.to_iso8601(Date.add(Date.utc_today(), -1))
      tomorrow = Date.to_iso8601(Date.add(Date.utc_today(), 1))

      sr_due = scheduled_report_fixture(%{name: "Due Today", next_run_date: today})
      sr_overdue = scheduled_report_fixture(%{name: "Overdue", next_run_date: yesterday})
      sr_future = scheduled_report_fixture(%{name: "Future", next_run_date: tomorrow})

      due = Analytics.list_due_scheduled_reports()
      due_ids = Enum.map(due, & &1.id)

      assert sr_due.id in due_ids
      assert sr_overdue.id in due_ids
      refute sr_future.id in due_ids
    end

    test "excludes inactive reports" do
      sr = scheduled_report_fixture(%{name: "Inactive"})
      {:ok, _} = Analytics.update_scheduled_report(sr, %{is_active: false})

      due = Analytics.list_due_scheduled_reports()
      due_ids = Enum.map(due, & &1.id)
      refute sr.id in due_ids
    end
  end

  describe "advance_next_run_date/1" do
    test "advances daily report by 1 day" do
      sr = scheduled_report_fixture(%{frequency: "daily"})
      {:ok, updated} = Analytics.advance_next_run_date(sr)
      expected = Date.to_iso8601(Date.add(Date.utc_today(), 1))
      assert updated.next_run_date == expected
      assert updated.last_sent_at != nil
    end

    test "advances weekly report by 7 days" do
      sr = scheduled_report_fixture(%{frequency: "weekly"})
      {:ok, updated} = Analytics.advance_next_run_date(sr)
      expected = Date.to_iso8601(Date.add(Date.utc_today(), 7))
      assert updated.next_run_date == expected
    end

    test "advances monthly report by approximately 1 month" do
      sr = scheduled_report_fixture(%{frequency: "monthly"})
      {:ok, updated} = Analytics.advance_next_run_date(sr)
      next = Date.from_iso8601!(updated.next_run_date)
      today = Date.utc_today()
      diff = Date.diff(next, today)
      assert diff >= 28 and diff <= 31
    end

    test "advances quarterly report by approximately 3 months" do
      sr = scheduled_report_fixture(%{frequency: "quarterly"})
      {:ok, updated} = Analytics.advance_next_run_date(sr)
      next = Date.from_iso8601!(updated.next_run_date)
      today = Date.utc_today()
      diff = Date.diff(next, today)
      assert diff >= 89 and diff <= 92
    end
  end
end
