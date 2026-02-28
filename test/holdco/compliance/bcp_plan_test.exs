defmodule Holdco.Compliance.BcpPlanTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "bcp_plans CRUD" do
    test "list_bcp_plans/0 returns all plans" do
      plan = bcp_plan_fixture()
      assert Enum.any?(Compliance.list_bcp_plans(), &(&1.id == plan.id))
    end

    test "list_bcp_plans/1 filters by company_id" do
      company = company_fixture()
      plan = bcp_plan_fixture(%{company: company})
      other = bcp_plan_fixture()

      results = Compliance.list_bcp_plans(company.id)
      assert Enum.any?(results, &(&1.id == plan.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_bcp_plan!/1 returns plan with preloads" do
      plan = bcp_plan_fixture()
      fetched = Compliance.get_bcp_plan!(plan.id)
      assert fetched.id == plan.id
      assert fetched.company != nil
    end

    test "get_bcp_plan!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_bcp_plan!(0)
      end
    end

    test "create_bcp_plan/1 with valid data" do
      company = company_fixture()

      assert {:ok, plan} =
               Compliance.create_bcp_plan(%{
                 company_id: company.id,
                 plan_name: "Primary DR Plan",
                 plan_type: "disaster_recovery",
                 version: "2.1",
                 status: "active",
                 approved_by: "Jane Smith",
                 approved_date: "2025-01-15",
                 next_test_date: "2025-06-15",
                 test_result: "passed",
                 rto_hours: 4,
                 rpo_hours: 1,
                 key_contacts: [%{"name" => "John", "role" => "IT Lead", "phone" => "555-0123"}],
                 critical_systems: ["ERP", "Email", "VPN"]
               })

      assert plan.plan_name == "Primary DR Plan"
      assert plan.plan_type == "disaster_recovery"
      assert plan.rto_hours == 4
      assert plan.rpo_hours == 1
      assert length(plan.key_contacts) == 1
      assert plan.critical_systems == ["ERP", "Email", "VPN"]
    end

    test "create_bcp_plan/1 with all plan types" do
      company = company_fixture()

      for plan_type <- ~w(disaster_recovery business_continuity pandemic cyber_incident financial_crisis) do
        assert {:ok, plan} =
                 Compliance.create_bcp_plan(%{
                   company_id: company.id,
                   plan_name: "Plan #{plan_type}",
                   plan_type: plan_type
                 })

        assert plan.plan_type == plan_type
      end
    end

    test "create_bcp_plan/1 with all statuses" do
      company = company_fixture()

      for status <- ~w(draft approved active under_review retired) do
        assert {:ok, plan} =
                 Compliance.create_bcp_plan(%{
                   company_id: company.id,
                   plan_name: "Plan #{status}",
                   plan_type: "business_continuity",
                   status: status
                 })

        assert plan.status == status
      end
    end

    test "create_bcp_plan/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_bcp_plan(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:plan_name]
    end

    test "create_bcp_plan/1 fails with invalid plan_type" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_bcp_plan(%{
                 company_id: company.id,
                 plan_name: "Bad Plan",
                 plan_type: "invalid"
               })

      assert errors_on(changeset)[:plan_type]
    end

    test "create_bcp_plan/1 fails with invalid test_result" do
      company = company_fixture()

      assert {:error, changeset} =
               Compliance.create_bcp_plan(%{
                 company_id: company.id,
                 plan_name: "Test Plan",
                 plan_type: "business_continuity",
                 test_result: "invalid"
               })

      assert errors_on(changeset)[:test_result]
    end

    test "update_bcp_plan/2 with valid data" do
      plan = bcp_plan_fixture()

      assert {:ok, updated} =
               Compliance.update_bcp_plan(plan, %{
                 version: "2.0",
                 status: "approved",
                 test_result: "passed",
                 last_tested_date: "2025-06-15"
               })

      assert updated.version == "2.0"
      assert updated.status == "approved"
      assert updated.test_result == "passed"
    end

    test "delete_bcp_plan/1 removes the plan" do
      plan = bcp_plan_fixture()
      assert {:ok, _} = Compliance.delete_bcp_plan(plan)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_bcp_plan!(plan.id)
      end
    end
  end

  describe "active_bcp_plans/1" do
    test "returns only active and approved plans" do
      company = company_fixture()
      active = bcp_plan_fixture(%{company: company, status: "active"})
      approved = bcp_plan_fixture(%{company: company, status: "approved"})
      _draft = bcp_plan_fixture(%{company: company, status: "draft"})
      _retired = bcp_plan_fixture(%{company: company, status: "retired"})

      results = Compliance.active_bcp_plans(company.id)
      ids = Enum.map(results, & &1.id)
      assert active.id in ids
      assert approved.id in ids
      assert length(results) == 2
    end
  end

  describe "plans_due_for_testing/0" do
    test "returns plans with past due test dates" do
      company = company_fixture()
      past_date = Date.add(Date.utc_today(), -30)
      future_date = Date.add(Date.utc_today(), 30)

      due = bcp_plan_fixture(%{company: company, status: "active", next_test_date: past_date})
      _not_due = bcp_plan_fixture(%{company: company, status: "active", next_test_date: future_date})
      _draft = bcp_plan_fixture(%{company: company, status: "draft", next_test_date: past_date})

      results = Compliance.plans_due_for_testing()
      ids = Enum.map(results, & &1.id)
      assert due.id in ids
      refute Enum.any?(results, &(&1.status == "draft"))
    end
  end
end
