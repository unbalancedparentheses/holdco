defmodule Holdco.Governance.EstatePlanningTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  describe "estate_plans CRUD" do
    test "list_estate_plans/0 returns all plans" do
      plan = estate_plan_fixture()
      assert Enum.any?(Governance.list_estate_plans(), &(&1.id == plan.id))
    end

    test "get_estate_plan!/1 returns plan with preloads" do
      plan = estate_plan_fixture()
      fetched = Governance.get_estate_plan!(plan.id)
      assert fetched.id == plan.id
    end

    test "get_estate_plan!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_estate_plan!(0)
      end
    end

    test "create_estate_plan/1 with valid data" do
      assert {:ok, plan} =
               Governance.create_estate_plan(%{
                 plan_name: "Smith Family Will",
                 plan_type: "will",
                 principal_name: "John Smith",
                 attorney_name: "Jane Attorney",
                 executor_name: "Bob Executor",
                 status: "executed",
                 effective_date: "2024-01-15",
                 estimated_estate_value: "10000000.00",
                 key_provisions: "Standard distribution provisions"
               })

      assert plan.plan_name == "Smith Family Will"
      assert plan.plan_type == "will"
      assert plan.principal_name == "John Smith"
      assert plan.status == "executed"
      assert Decimal.equal?(plan.estimated_estate_value, Decimal.new("10000000.00"))
    end

    test "create_estate_plan/1 with family charter association" do
      charter = family_charter_fixture()

      assert {:ok, plan} =
               Governance.create_estate_plan(%{
                 family_charter_id: charter.id,
                 plan_name: "Charter-linked Plan",
                 plan_type: "trust",
                 principal_name: "Principal"
               })

      assert plan.family_charter_id == charter.id
    end

    test "create_estate_plan/1 with all plan types" do
      for type <- ~w(will trust power_of_attorney healthcare_directive beneficiary_designation buy_sell_agreement) do
        assert {:ok, plan} =
                 Governance.create_estate_plan(%{
                   plan_name: "Plan #{type}",
                   plan_type: type,
                   principal_name: "Principal"
                 })

        assert plan.plan_type == type
      end
    end

    test "create_estate_plan/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_estate_plan(%{})
      errors = errors_on(changeset)
      assert errors[:plan_name]
      assert errors[:plan_type]
      assert errors[:principal_name]
    end

    test "create_estate_plan/1 fails with invalid plan type" do
      assert {:error, changeset} =
               Governance.create_estate_plan(%{
                 plan_name: "Test",
                 plan_type: "invalid",
                 principal_name: "Principal"
               })

      assert errors_on(changeset)[:plan_type]
    end

    test "update_estate_plan/2 with valid data" do
      plan = estate_plan_fixture()

      assert {:ok, updated} =
               Governance.update_estate_plan(plan, %{
                 plan_name: "Updated Plan",
                 status: "executed",
                 effective_date: "2025-01-01"
               })

      assert updated.plan_name == "Updated Plan"
      assert updated.status == "executed"
    end

    test "delete_estate_plan/1 removes the plan" do
      plan = estate_plan_fixture()
      assert {:ok, _} = Governance.delete_estate_plan(plan)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_estate_plan!(plan.id)
      end
    end
  end

  describe "plans_due_for_review/0" do
    test "returns plans with past review dates" do
      past_date = Date.add(Date.utc_today(), -30)
      future_date = Date.add(Date.utc_today(), 30)

      due = estate_plan_fixture(%{next_review_date: past_date, status: "executed"})
      _not_due = estate_plan_fixture(%{next_review_date: future_date, status: "executed"})
      _revoked = estate_plan_fixture(%{next_review_date: past_date, status: "revoked"})

      results = Governance.plans_due_for_review()
      assert Enum.any?(results, &(&1.id == due.id))
      refute Enum.any?(results, fn p -> p.status == "revoked" end)
    end
  end

  describe "succession_plans CRUD" do
    test "list_succession_plans/0 returns all plans" do
      plan = succession_plan_fixture()
      assert Enum.any?(Governance.list_succession_plans(), &(&1.id == plan.id))
    end

    test "list_succession_plans/1 filters by company_id" do
      company = company_fixture()
      plan = succession_plan_fixture(%{company: company})
      other = succession_plan_fixture()

      results = Governance.list_succession_plans(company.id)
      assert Enum.any?(results, &(&1.id == plan.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "get_succession_plan!/1 returns plan with preloads" do
      plan = succession_plan_fixture()
      fetched = Governance.get_succession_plan!(plan.id)
      assert fetched.id == plan.id
      assert fetched.company != nil
    end

    test "create_succession_plan/1 with valid data" do
      company = company_fixture()

      assert {:ok, plan} =
               Governance.create_succession_plan(%{
                 company_id: company.id,
                 position_title: "CEO",
                 current_holder: "John Smith",
                 successor_candidates: [
                   %{"name" => "Alice", "readiness" => "ready", "development_plan" => "None"},
                   %{"name" => "Bob", "readiness" => "developing", "development_plan" => "Leadership program"}
                 ],
                 timeline: "short_term",
                 status: "active",
                 trigger_events: ["retirement", "incapacity"]
               })

      assert plan.position_title == "CEO"
      assert plan.current_holder == "John Smith"
      assert length(plan.successor_candidates) == 2
      assert plan.trigger_events == ["retirement", "incapacity"]
    end

    test "create_succession_plan/1 fails without required fields" do
      assert {:error, changeset} = Governance.create_succession_plan(%{})
      errors = errors_on(changeset)
      assert errors[:company_id]
      assert errors[:position_title]
      assert errors[:current_holder]
    end

    test "update_succession_plan/2 with valid data" do
      plan = succession_plan_fixture()

      assert {:ok, updated} =
               Governance.update_succession_plan(plan, %{
                 status: "triggered",
                 timeline: "immediate"
               })

      assert updated.status == "triggered"
      assert updated.timeline == "immediate"
    end

    test "delete_succession_plan/1 removes the plan" do
      plan = succession_plan_fixture()
      assert {:ok, _} = Governance.delete_succession_plan(plan)

      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_succession_plan!(plan.id)
      end
    end
  end

  describe "active_succession_plans/1" do
    test "returns only active plans for company" do
      company = company_fixture()
      active = succession_plan_fixture(%{company: company, status: "active"})
      _completed = succession_plan_fixture(%{company: company, status: "completed"})
      _other_company = succession_plan_fixture(%{status: "active"})

      results = Governance.active_succession_plans(company.id)
      assert length(results) == 1
      assert Enum.any?(results, &(&1.id == active.id))
    end
  end
end
