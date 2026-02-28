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
  end
end
