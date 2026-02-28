defmodule Holdco.Workers.ScheduledReportWorkerTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Workers.ScheduledReportWorker
  alias Holdco.Analytics

  describe "perform/1" do
    test "processes due scheduled reports and advances next_run_date" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "Worker Test Report",
          report_type: "portfolio_summary",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      assert updated.next_run_date != today
      assert updated.last_sent_at != nil
    end

    test "skips reports with future next_run_date" do
      tomorrow = Date.to_iso8601(Date.add(Date.utc_today(), 1))

      sr =
        scheduled_report_fixture(%{
          name: "Future Report",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: tomorrow
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      assert updated.next_run_date == tomorrow
      assert updated.last_sent_at == nil
    end

    test "skips inactive reports" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "Inactive Report",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: today
        })

      {:ok, _} = Analytics.update_scheduled_report(sr, %{is_active: false})

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      assert updated.last_sent_at == nil
    end

    test "handles reports with no valid recipients gracefully" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "No Recipients Report",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: today
        })

      # Update recipients to contain only whitespace/empty via direct DB update
      Holdco.Repo.update!(Ecto.Changeset.change(sr, recipients: "  ,  , "))

      # Should not raise
      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end

    test "returns :ok when no reports are due" do
      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end
  end

  describe "generate_report_content/1" do
    test "generates portfolio_summary content" do
      sr = scheduled_report_fixture(%{report_type: "portfolio_summary"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Portfolio Summary"
      assert content =~ "Net Asset Value"
    end

    test "generates financial_report content" do
      sr = scheduled_report_fixture(%{report_type: "financial_report"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Financial Report"
      assert content =~ "Trial Balance"
      assert content =~ "Income Statement"
    end

    test "generates compliance_report content" do
      sr = scheduled_report_fixture(%{report_type: "compliance_report"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Compliance Report"
      assert content =~ "Upcoming Deadlines"
    end

    test "generates board_pack content combining all sections" do
      sr = scheduled_report_fixture(%{report_type: "board_pack"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Board Pack"
      assert content =~ "Portfolio Summary"
      assert content =~ "Financial Report"
      assert content =~ "Compliance Report"
    end

    test "returns unknown report type message for unrecognized types" do
      # Build a struct directly since the DB schema validates report_type
      sr = %Holdco.Analytics.ScheduledReport{report_type: "custom_report"}
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Unknown report type"
      assert content =~ "custom_report"
    end

    test "portfolio_summary includes table structure" do
      sr = scheduled_report_fixture(%{report_type: "portfolio_summary"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "<table"
      assert content =~ "Liquid Assets"
      assert content =~ "Marketable Securities"
      assert content =~ "Illiquid Holdings"
      assert content =~ "Total Liabilities"
      assert content =~ "Generated on"
    end

    test "financial_report includes net income" do
      sr = scheduled_report_fixture(%{report_type: "financial_report"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Net Income"
    end

    test "compliance_report shows 'No upcoming deadlines' when none exist" do
      sr = scheduled_report_fixture(%{report_type: "compliance_report"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "No upcoming deadlines"
    end

    test "board_pack includes horizontal rule separators" do
      sr = scheduled_report_fixture(%{report_type: "board_pack"})
      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "<hr/>"
    end
  end

  # ── perform/1 edge cases ────────────────────────────

  describe "perform/1 edge cases" do
    test "handles nil next_run_date (always due)" do
      sr =
        scheduled_report_fixture(%{
          name: "Nil Date Report",
          report_type: "portfolio_summary",
          frequency: "daily",
          recipients: "test@example.com"
        })

      # Set next_run_date to nil via direct DB update
      Holdco.Repo.update!(Ecto.Changeset.change(sr, next_run_date: nil))

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      assert updated.last_sent_at != nil
    end

    test "handles whitespace-only recipients (skips sending)" do
      sr =
        scheduled_report_fixture(%{
          name: "Whitespace Recipients Report",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: Date.to_iso8601(Date.utc_today())
        })

      # Set recipients to whitespace-only (not nil, since DB has NOT NULL constraint)
      Holdco.Repo.update!(Ecto.Changeset.change(sr, recipients: "   "))

      # Should not crash -- parse_recipients will filter to empty list
      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end

    test "handles empty string recipients (skips sending)" do
      sr =
        scheduled_report_fixture(%{
          name: "Empty Recipients Report",
          frequency: "daily",
          recipients: "test@example.com",
          next_run_date: Date.to_iso8601(Date.utc_today())
        })

      Holdco.Repo.update!(Ecto.Changeset.change(sr, recipients: ""))

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end

    test "sends to multiple recipients" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "Multi Recipients",
          report_type: "portfolio_summary",
          frequency: "daily",
          recipients: "alice@example.com, bob@example.com, charlie@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      assert updated.last_sent_at != nil
      assert updated.next_run_date != today
    end

    test "processes multiple due reports in one run" do
      today = Date.to_iso8601(Date.utc_today())

      sr1 =
        scheduled_report_fixture(%{
          name: "Report A",
          report_type: "portfolio_summary",
          frequency: "daily",
          recipients: "a@example.com",
          next_run_date: today
        })

      sr2 =
        scheduled_report_fixture(%{
          name: "Report B",
          report_type: "compliance_report",
          frequency: "daily",
          recipients: "b@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated1 = Analytics.get_scheduled_report!(sr1.id)
      updated2 = Analytics.get_scheduled_report!(sr2.id)

      assert updated1.last_sent_at != nil
      assert updated2.last_sent_at != nil
    end

    test "csv format report sends plain text email" do
      today = Date.to_iso8601(Date.utc_today())

      _sr =
        scheduled_report_fixture(%{
          name: "CSV Report",
          report_type: "portfolio_summary",
          frequency: "daily",
          format: "csv",
          recipients: "test@example.com",
          next_run_date: today
        })

      # Should not crash -- csv format path
      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end

    test "html format report sends html email with wrapped content" do
      today = Date.to_iso8601(Date.utc_today())

      _sr =
        scheduled_report_fixture(%{
          name: "HTML Report",
          report_type: "portfolio_summary",
          frequency: "daily",
          format: "html",
          recipients: "test@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})
    end

    test "weekly frequency advances next_run_date by 7 days" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "Weekly Report",
          report_type: "portfolio_summary",
          frequency: "weekly",
          recipients: "test@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      expected_next = Date.to_iso8601(Date.add(Date.utc_today(), 7))
      assert updated.next_run_date == expected_next
    end

    test "monthly frequency advances next_run_date by about a month" do
      today = Date.to_iso8601(Date.utc_today())

      sr =
        scheduled_report_fixture(%{
          name: "Monthly Report",
          report_type: "portfolio_summary",
          frequency: "monthly",
          recipients: "test@example.com",
          next_run_date: today
        })

      assert :ok = ScheduledReportWorker.perform(%Oban.Job{})

      updated = Analytics.get_scheduled_report!(sr.id)
      next_date = Date.from_iso8601!(updated.next_run_date)
      # Monthly should advance to next month
      assert Date.diff(next_date, Date.utc_today()) >= 28
      assert Date.diff(next_date, Date.utc_today()) <= 31
    end
  end

  # ── generate_report_content/1 with real data ────────

  describe "generate_report_content/1 with compliance deadlines" do
    test "includes upcoming deadlines when they exist within 90 days" do
      company = company_fixture()

      {:ok, _deadline} =
        Holdco.Compliance.create_tax_deadline(%{
          company_id: company.id,
          description: "Annual filing test",
          due_date: Date.to_iso8601(Date.add(Date.utc_today(), 30)),
          jurisdiction: "US",
          status: "pending"
        })

      sr =
        scheduled_report_fixture(%{
          company: company,
          report_type: "compliance_report"
        })

      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "Annual filing test"
      assert content =~ "US"
    end

    test "marks deadlines within 14 days with red color" do
      company = company_fixture()

      {:ok, _deadline} =
        Holdco.Compliance.create_tax_deadline(%{
          company_id: company.id,
          description: "Urgent filing",
          due_date: Date.to_iso8601(Date.add(Date.utc_today(), 5)),
          jurisdiction: "UK",
          status: "pending"
        })

      sr =
        scheduled_report_fixture(%{
          company: company,
          report_type: "compliance_report"
        })

      content = ScheduledReportWorker.generate_report_content(sr)
      assert content =~ "color: red"
      assert content =~ "Urgent filing"
    end

    test "excludes completed deadlines" do
      company = company_fixture()

      {:ok, _deadline} =
        Holdco.Compliance.create_tax_deadline(%{
          company_id: company.id,
          description: "Completed filing",
          due_date: Date.to_iso8601(Date.add(Date.utc_today(), 10)),
          jurisdiction: "US",
          status: "completed"
        })

      sr =
        scheduled_report_fixture(%{
          company: company,
          report_type: "compliance_report"
        })

      content = ScheduledReportWorker.generate_report_content(sr)
      refute content =~ "Completed filing"
    end
  end
end
