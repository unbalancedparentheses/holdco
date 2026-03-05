defmodule Holdco.FundraisingTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Fund

  # ── Fundraising Pipeline CRUD ──────────────────────────

  describe "list_fundraising_pipelines/1" do
    test "returns all pipelines" do
      pipeline = fundraising_pipeline_fixture()
      pipelines = Fund.list_fundraising_pipelines()
      assert length(pipelines) >= 1
      assert Enum.any?(pipelines, &(&1.id == pipeline.id))
    end

    test "filters by company_id" do
      c1 = company_fixture(%{name: "FundRaise1"})
      c2 = company_fixture(%{name: "FundRaise2"})
      p1 = fundraising_pipeline_fixture(%{company: c1})
      _p2 = fundraising_pipeline_fixture(%{company: c2})

      pipelines = Fund.list_fundraising_pipelines(c1.id)
      assert length(pipelines) == 1
      assert hd(pipelines).id == p1.id
    end

    test "returns empty list when no pipelines for company" do
      company = company_fixture()
      assert Fund.list_fundraising_pipelines(company.id) == []
    end
  end

  describe "get_fundraising_pipeline!/1" do
    test "returns the pipeline with given id" do
      pipeline = fundraising_pipeline_fixture()
      found = Fund.get_fundraising_pipeline!(pipeline.id)
      assert found.id == pipeline.id
      assert found.fund_name == pipeline.fund_name
    end

    test "preloads company and prospects" do
      pipeline = fundraising_pipeline_fixture()
      found = Fund.get_fundraising_pipeline!(pipeline.id)
      assert found.company != nil
      assert is_list(found.prospects)
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fundraising_pipeline!(0)
      end
    end
  end

  describe "create_fundraising_pipeline/1" do
    test "creates a pipeline with valid attrs" do
      company = company_fixture()

      assert {:ok, pipeline} =
               Fund.create_fundraising_pipeline(%{
                 company_id: company.id,
                 fund_name: "Growth Fund I",
                 target_amount: 50_000_000.0,
                 hard_cap: 75_000_000.0,
                 soft_cap: 40_000_000.0,
                 management_fee_rate: 2.0,
                 carried_interest_rate: 20.0,
                 hurdle_rate: 8.0,
                 fund_term_years: 10
               })

      assert pipeline.fund_name == "Growth Fund I"
      assert pipeline.status == "prospecting"
      assert Decimal.equal?(pipeline.target_amount, Decimal.from_float(50_000_000.0))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_fundraising_pipeline(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:fund_name]
      assert errors[:target_amount]
    end

    test "validates status inclusion" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_fundraising_pipeline(%{
                 company_id: company.id,
                 fund_name: "Bad Status Fund",
                 target_amount: 1_000_000.0,
                 status: "invalid_status"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "validates target_amount is positive" do
      company = company_fixture()

      assert {:error, changeset} =
               Fund.create_fundraising_pipeline(%{
                 company_id: company.id,
                 fund_name: "Zero Fund",
                 target_amount: -1.0
               })

      assert %{target_amount: _} = errors_on(changeset)
    end
  end

  describe "update_fundraising_pipeline/2" do
    test "updates a pipeline" do
      pipeline = fundraising_pipeline_fixture()
      assert {:ok, updated} = Fund.update_fundraising_pipeline(pipeline, %{status: "marketing"})
      assert updated.status == "marketing"
    end

    test "updates fund_name" do
      pipeline = fundraising_pipeline_fixture()
      assert {:ok, updated} = Fund.update_fundraising_pipeline(pipeline, %{fund_name: "Renamed Fund"})
      assert updated.fund_name == "Renamed Fund"
    end

    test "rejects invalid status update" do
      pipeline = fundraising_pipeline_fixture()

      assert {:error, changeset} =
               Fund.update_fundraising_pipeline(pipeline, %{status: "nonexistent"})

      assert %{status: _} = errors_on(changeset)
    end
  end

  describe "delete_fundraising_pipeline/1" do
    test "deletes the pipeline" do
      pipeline = fundraising_pipeline_fixture()
      assert {:ok, _} = Fund.delete_fundraising_pipeline(pipeline)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_fundraising_pipeline!(pipeline.id)
      end
    end
  end

  # ── Prospect CRUD ──────────────────────────────────────

  describe "list_prospects/1" do
    test "returns prospects for a pipeline" do
      pipeline = fundraising_pipeline_fixture()
      prospect = prospect_fixture(%{pipeline: pipeline})
      prospects = Fund.list_prospects(pipeline.id)
      assert length(prospects) >= 1
      assert Enum.any?(prospects, &(&1.id == prospect.id))
    end

    test "returns empty list when no prospects" do
      pipeline = fundraising_pipeline_fixture()
      assert Fund.list_prospects(pipeline.id) == []
    end
  end

  describe "get_prospect!/1" do
    test "returns the prospect with given id" do
      prospect = prospect_fixture()
      found = Fund.get_prospect!(prospect.id)
      assert found.id == prospect.id
      assert found.investor_name == prospect.investor_name
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_prospect!(0)
      end
    end
  end

  describe "create_prospect/1" do
    test "creates a prospect with valid attrs" do
      pipeline = fundraising_pipeline_fixture()

      assert {:ok, prospect} =
               Fund.create_prospect(%{
                 pipeline_id: pipeline.id,
                 investor_name: "Acme Capital",
                 contact_email: "invest@acme.com",
                 commitment_amount: 5_000_000.0,
                 status: "contacted"
               })

      assert prospect.investor_name == "Acme Capital"
      assert prospect.status == "contacted"
    end

    test "defaults status to identified" do
      pipeline = fundraising_pipeline_fixture()

      assert {:ok, prospect} =
               Fund.create_prospect(%{
                 pipeline_id: pipeline.id,
                 investor_name: "Default Status"
               })

      assert prospect.status == "identified"
    end

    test "fails without required fields" do
      assert {:error, changeset} = Fund.create_prospect(%{})
      errors = errors_on(changeset)
      assert errors[:pipeline_id]
      assert errors[:investor_name]
    end

    test "validates status inclusion" do
      pipeline = fundraising_pipeline_fixture()

      assert {:error, changeset} =
               Fund.create_prospect(%{
                 pipeline_id: pipeline.id,
                 investor_name: "Bad Status",
                 status: "invalid"
               })

      assert %{status: _} = errors_on(changeset)
    end

    test "validates email format" do
      pipeline = fundraising_pipeline_fixture()

      assert {:error, changeset} =
               Fund.create_prospect(%{
                 pipeline_id: pipeline.id,
                 investor_name: "Bad Email",
                 contact_email: "not-an-email"
               })

      assert %{contact_email: _} = errors_on(changeset)
    end
  end

  describe "update_prospect/2" do
    test "updates a prospect" do
      prospect = prospect_fixture()
      assert {:ok, updated} = Fund.update_prospect(prospect, %{status: "committed"})
      assert updated.status == "committed"
    end

    test "updates commitment amount" do
      prospect = prospect_fixture()

      assert {:ok, updated} =
               Fund.update_prospect(prospect, %{commitment_amount: 10_000_000.0})

      assert Decimal.equal?(updated.commitment_amount, Decimal.from_float(10_000_000.0))
    end
  end

  describe "delete_prospect/1" do
    test "deletes the prospect" do
      prospect = prospect_fixture()
      assert {:ok, _} = Fund.delete_prospect(prospect)

      assert_raise Ecto.NoResultsError, fn ->
        Fund.get_prospect!(prospect.id)
      end
    end
  end

  # ── Pipeline Summary ───────────────────────────────────

  describe "pipeline_summary/1" do
    test "returns summary with zero committed when no prospects" do
      pipeline = fundraising_pipeline_fixture()
      summary = Fund.pipeline_summary(pipeline.id)

      assert summary.pipeline.id == pipeline.id
      assert Decimal.equal?(summary.total_committed, Decimal.new(0))
      assert summary.committed_count == 0
      assert Decimal.equal?(summary.progress_pct, Decimal.new(0))
    end

    test "aggregates committed prospect amounts" do
      pipeline = fundraising_pipeline_fixture(%{target_amount: 10_000_000.0})

      prospect_fixture(%{pipeline: pipeline, status: "committed", commitment_amount: 3_000_000.0})
      prospect_fixture(%{pipeline: pipeline, status: "committed", commitment_amount: 2_000_000.0})
      prospect_fixture(%{pipeline: pipeline, status: "interested", commitment_amount: 1_000_000.0})

      summary = Fund.pipeline_summary(pipeline.id)

      assert Decimal.equal?(summary.total_committed, Decimal.from_float(5_000_000.0))
      assert summary.committed_count == 2
      assert Decimal.equal?(summary.progress_pct, Decimal.new("50.00"))
    end

    test "returns prospect counts by status" do
      pipeline = fundraising_pipeline_fixture()

      prospect_fixture(%{pipeline: pipeline, status: "identified"})
      prospect_fixture(%{pipeline: pipeline, status: "identified"})
      prospect_fixture(%{pipeline: pipeline, status: "contacted"})
      prospect_fixture(%{pipeline: pipeline, status: "committed", commitment_amount: 100.0})

      summary = Fund.pipeline_summary(pipeline.id)

      assert Map.get(summary.prospect_counts, "identified") == 2
      assert Map.get(summary.prospect_counts, "contacted") == 1
      assert Map.get(summary.prospect_counts, "committed") == 1
    end
  end
end
