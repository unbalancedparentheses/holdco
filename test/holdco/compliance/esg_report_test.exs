defmodule Holdco.Compliance.EsgReportTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "esg_reports CRUD" do
    test "list_esg_reports/0 returns all reports" do
      report = esg_report_fixture()
      assert Enum.any?(Compliance.list_esg_reports(), &(&1.id == report.id))
    end

    test "list_esg_reports/1 filters by company_id" do
      company = company_fixture()
      report = esg_report_fixture(%{company: company})
      other = esg_report_fixture()

      results = Compliance.list_esg_reports(company.id)
      assert Enum.any?(results, &(&1.id == report.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_esg_report!/1 returns report with preloads" do
      report = esg_report_fixture()
      fetched = Compliance.get_esg_report!(report.id)
      assert fetched.id == report.id
      assert fetched.company != nil
    end

    test "get_esg_report!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_esg_report!(0)
      end
    end

    test "create_esg_report/1 with valid data" do
      company = company_fixture()

      assert {:ok, report} =
               Compliance.create_esg_report(%{
                 company_id: company.id,
                 framework: "gri",
                 reporting_period_start: "2025-01-01",
                 reporting_period_end: "2025-12-31",
                 title: "Annual ESG Report 2025",
                 score: "92.5",
                 status: "draft",
                 metrics: %{"carbon_intensity" => "0.5", "diversity_ratio" => "0.45"}
               })

      assert report.framework == "gri"
      assert report.title == "Annual ESG Report 2025"
      assert Decimal.equal?(report.score, Decimal.new("92.5"))
      assert report.metrics == %{"carbon_intensity" => "0.5", "diversity_ratio" => "0.45"}
    end

    test "create_esg_report/1 with all frameworks" do
      company = company_fixture()

      for framework <- ~w(gri sasb tcfd custom) do
        assert {:ok, report} =
                 Compliance.create_esg_report(%{
                   company_id: company.id,
                   framework: framework,
                   reporting_period_start: "2025-01-01",
                   reporting_period_end: "2025-12-31",
                   title: "Report #{framework}"
                 })

        assert report.framework == framework
      end
    end

    test "create_esg_report/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_esg_report(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:title]
      assert errors[:reporting_period_start]
      assert errors[:reporting_period_end]
    end

    test "create_esg_report/1 fails with invalid framework" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_esg_report(%{
                 company_id: company.id,
                 framework: "invalid",
                 reporting_period_start: "2025-01-01",
                 reporting_period_end: "2025-12-31",
                 title: "Test"
               })

      assert errors_on(changeset)[:framework]
    end

    test "create_esg_report/1 fails with invalid status" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_esg_report(%{
                 company_id: company.id,
                 framework: "gri",
                 reporting_period_start: "2025-01-01",
                 reporting_period_end: "2025-12-31",
                 title: "Test",
                 status: "invalid_status"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_esg_report/2 with valid data" do
      report = esg_report_fixture()

      assert {:ok, updated} =
               Compliance.update_esg_report(report, %{
                 title: "Updated Title",
                 score: "95.0",
                 status: "published",
                 published_date: "2026-01-15"
               })

      assert updated.title == "Updated Title"
      assert Decimal.equal?(updated.score, Decimal.new("95.0"))
      assert updated.status == "published"
    end

    test "delete_esg_report/1 removes the report" do
      report = esg_report_fixture()
      assert {:ok, _} = Compliance.delete_esg_report(report)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_esg_report!(report.id)
      end
    end
  end

  describe "latest_esg_report/1" do
    test "returns the most recent report for a company" do
      company = company_fixture()
      _old = esg_report_fixture(%{company: company, reporting_period_end: "2024-12-31", title: "Old"})
      new = esg_report_fixture(%{company: company, reporting_period_end: "2025-12-31", title: "New"})

      result = Compliance.latest_esg_report(company.id)
      assert result.id == new.id
    end

    test "returns nil when no reports exist" do
      company = company_fixture()
      assert Compliance.latest_esg_report(company.id) == nil
    end
  end

  describe "esg_trend/1" do
    test "returns scores ordered by period end" do
      company = company_fixture()
      esg_report_fixture(%{company: company, reporting_period_end: "2023-12-31", score: "80.0", title: "2023"})
      esg_report_fixture(%{company: company, reporting_period_end: "2024-12-31", score: "85.0", title: "2024"})
      esg_report_fixture(%{company: company, reporting_period_end: "2025-12-31", score: "90.0", title: "2025"})

      trend = Compliance.esg_trend(company.id)
      assert length(trend) == 3
      scores = Enum.map(trend, & &1.score)
      assert Decimal.equal?(Enum.at(scores, 0), Decimal.new("80.0"))
      assert Decimal.equal?(Enum.at(scores, 2), Decimal.new("90.0"))
    end

    test "excludes reports without scores" do
      company = company_fixture()
      esg_report_fixture(%{company: company, score: "80.0"})
      esg_report_fixture(%{company: company, score: nil})

      trend = Compliance.esg_trend(company.id)
      assert length(trend) == 1
    end
  end
end
