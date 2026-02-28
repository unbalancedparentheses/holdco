defmodule Holdco.Governance.EthicsReportTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  describe "ethics_reports CRUD" do
    test "list_ethics_reports/0 returns all reports" do
      report = ethics_report_fixture()
      assert Enum.any?(Governance.list_ethics_reports(), &(&1.id == report.id))
    end

    test "list_ethics_reports/1 filters by company_id" do
      company = company_fixture()
      report = ethics_report_fixture(%{company: company})
      other = ethics_report_fixture()

      results = Governance.list_ethics_reports(company.id)
      assert Enum.any?(results, &(&1.id == report.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_ethics_report!/1 returns report with preloads" do
      report = ethics_report_fixture()
      fetched = Governance.get_ethics_report!(report.id)
      assert fetched.id == report.id
      assert fetched.company != nil
    end

    test "get_ethics_report!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_ethics_report!(0)
      end
    end

    test "create_ethics_report/1 with valid data" do
      company = company_fixture()

      assert {:ok, report} =
               Governance.create_ethics_report(%{
                 company_id: company.id,
                 report_type: "whistleblower",
                 reporter_type: "anonymous",
                 severity: "high",
                 description: "Potential accounting irregularities in Q3 reports",
                 involved_parties: "Finance department",
                 status: "received",
                 reported_date: "2025-06-15",
                 notes: "Submitted through hotline"
               })

      assert report.report_type == "whistleblower"
      assert report.reporter_type == "anonymous"
      assert report.severity == "high"
      assert report.description == "Potential accounting irregularities in Q3 reports"
    end

    test "create_ethics_report/1 with all report types" do
      company = company_fixture()

      for report_type <- ~w(whistleblower ethics_violation harassment fraud conflict_of_interest data_breach other) do
        assert {:ok, report} =
                 Governance.create_ethics_report(%{
                   company_id: company.id,
                   report_type: report_type,
                   reporter_type: "anonymous",
                   severity: "medium",
                   description: "Test #{report_type}",
                   reported_date: "2025-06-15"
                 })

        assert report.report_type == report_type
      end
    end

    test "create_ethics_report/1 with all reporter types" do
      company = company_fixture()

      for reporter_type <- ~w(anonymous named_internal named_external) do
        assert {:ok, report} =
                 Governance.create_ethics_report(%{
                   company_id: company.id,
                   report_type: "whistleblower",
                   reporter_type: reporter_type,
                   severity: "medium",
                   description: "Test reporter type",
                   reported_date: "2025-06-15"
                 })

        assert report.reporter_type == reporter_type
      end
    end

    test "create_ethics_report/1 with all severities" do
      company = company_fixture()

      for severity <- ~w(low medium high critical) do
        assert {:ok, report} =
                 Governance.create_ethics_report(%{
                   company_id: company.id,
                   report_type: "whistleblower",
                   reporter_type: "anonymous",
                   severity: severity,
                   description: "Test severity",
                   reported_date: "2025-06-15"
                 })

        assert report.severity == severity
      end
    end

    test "create_ethics_report/1 with named reporter" do
      company = company_fixture()

      assert {:ok, report} =
               Governance.create_ethics_report(%{
                 company_id: company.id,
                 report_type: "harassment",
                 reporter_type: "named_internal",
                 reporter_name: "Jane Doe",
                 severity: "high",
                 description: "Harassment complaint",
                 reported_date: "2025-06-15"
               })

      assert report.reporter_name == "Jane Doe"
    end

    test "create_ethics_report/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_ethics_report(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:description]
      assert errors[:reported_date]
    end

    test "create_ethics_report/1 fails with invalid report_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Governance.create_ethics_report(%{
                 company_id: company.id,
                 report_type: "invalid",
                 reporter_type: "anonymous",
                 severity: "medium",
                 description: "Test",
                 reported_date: "2025-06-15"
               })

      assert errors_on(changeset)[:report_type]
    end

    test "create_ethics_report/1 fails with invalid severity" do
      company = company_fixture()

      assert {:error, changeset} =
               Governance.create_ethics_report(%{
                 company_id: company.id,
                 report_type: "whistleblower",
                 reporter_type: "anonymous",
                 severity: "invalid",
                 description: "Test",
                 reported_date: "2025-06-15"
               })

      assert errors_on(changeset)[:severity]
    end

    test "update_ethics_report/2 with valid data" do
      report = ethics_report_fixture()

      assert {:ok, updated} =
               Governance.update_ethics_report(report, %{
                 status: "under_investigation",
                 assigned_investigator: "John Smith",
                 investigation_notes: "Investigation started on 2025-07-01"
               })

      assert updated.status == "under_investigation"
      assert updated.assigned_investigator == "John Smith"
    end

    test "update_ethics_report/2 to resolved status" do
      report = ethics_report_fixture()

      assert {:ok, updated} =
               Governance.update_ethics_report(report, %{
                 status: "resolved",
                 resolution: "Investigation found no evidence of wrongdoing",
                 resolved_date: "2025-08-15"
               })

      assert updated.status == "resolved"
      assert updated.resolution == "Investigation found no evidence of wrongdoing"
    end

    test "delete_ethics_report/1 removes the report" do
      report = ethics_report_fixture()
      assert {:ok, _} = Governance.delete_ethics_report(report)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_ethics_report!(report.id)
      end
    end
  end

  describe "open_ethics_reports/1" do
    test "returns only open reports for a company" do
      company = company_fixture()
      received = ethics_report_fixture(%{company: company, status: "received"})
      investigating = ethics_report_fixture(%{company: company, status: "under_investigation"})
      escalated = ethics_report_fixture(%{company: company, status: "escalated"})
      _resolved = ethics_report_fixture(%{company: company, status: "resolved"})
      _dismissed = ethics_report_fixture(%{company: company, status: "dismissed"})

      results = Governance.open_ethics_reports(company.id)
      ids = Enum.map(results, & &1.id)
      assert received.id in ids
      assert investigating.id in ids
      assert escalated.id in ids
      assert length(results) == 3
    end
  end

  describe "ethics_summary/1" do
    test "returns summary grouped by status, severity, and type" do
      company = company_fixture()
      ethics_report_fixture(%{company: company, status: "received", severity: "high", report_type: "fraud"})
      ethics_report_fixture(%{company: company, status: "received", severity: "medium", report_type: "whistleblower"})
      ethics_report_fixture(%{company: company, status: "resolved", severity: "low", report_type: "fraud"})

      summary = Governance.ethics_summary(company.id)

      assert length(summary.by_status) >= 2
      assert length(summary.by_severity) >= 2
      assert length(summary.by_type) >= 1
    end

    test "returns empty summary when no reports" do
      company = company_fixture()
      summary = Governance.ethics_summary(company.id)

      assert summary.by_status == []
      assert summary.by_severity == []
      assert summary.by_type == []
    end

    test "returns global summary without company_id" do
      ethics_report_fixture()
      ethics_report_fixture()

      summary = Governance.ethics_summary()
      total = Enum.reduce(summary.by_status, 0, fn s, acc -> acc + s.count end)
      assert total >= 2
    end
  end
end
