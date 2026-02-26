defmodule Holdco.GovernanceTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Governance

  # ── Board Meetings ────────────────────────────────────

  describe "board_meetings" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-03-15"})

      assert Enum.any?(Governance.list_board_meetings(company.id), &(&1.id == bm.id))
      assert Enum.any?(Governance.list_board_meetings(), &(&1.id == bm.id))
      assert Governance.get_board_meeting!(bm.id).id == bm.id

      {:ok, updated} = Governance.update_board_meeting(bm, %{status: "completed"})
      assert updated.status == "completed"

      {:ok, _} = Governance.delete_board_meeting(updated)
    end

    test "list_board_meetings/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      {:ok, bm1} = Governance.create_board_meeting(%{company_id: company1.id, scheduled_date: "2024-03-15"})
      {:ok, _bm2} = Governance.create_board_meeting(%{company_id: company2.id, scheduled_date: "2024-04-15"})

      meetings = Governance.list_board_meetings(company1.id)
      assert Enum.all?(meetings, &(&1.company_id == company1.id))
      assert Enum.any?(meetings, &(&1.id == bm1.id))
    end

    test "list_board_meetings/0 returns all board meetings" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_board_meeting(%{company_id: company1.id, scheduled_date: "2024-03-15"})
      Governance.create_board_meeting(%{company_id: company2.id, scheduled_date: "2024-04-15"})

      all = Governance.list_board_meetings()
      assert length(all) >= 2
    end

    test "list_board_meetings/0 orders by scheduled_date desc" do
      company = company_fixture()
      Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-01-01"})
      Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-12-31"})

      meetings = Governance.list_board_meetings(company.id)
      dates = Enum.map(meetings, & &1.scheduled_date)
      assert dates == Enum.sort(dates, :desc)
    end

    test "get_board_meeting!/1 preloads company" do
      company = company_fixture()
      {:ok, bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-03-15"})
      fetched = Governance.get_board_meeting!(bm.id)
      assert fetched.company.id == company.id
    end

    test "get_board_meeting!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_board_meeting!(-1)
      end
    end

    test "create_board_meeting/1 creates audit log" do
      company = company_fixture()
      {:ok, _bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-03-15"})
      logs = Holdco.Platform.list_audit_logs(%{table_name: "board_meetings"})
      assert length(logs) > 0
    end
  end

  # ── Cap Table Entries ─────────────────────────────────

  describe "cap_table_entries" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, ct} = Governance.create_cap_table_entry(%{company_id: company.id, investor: "VC Fund", round_name: "Seed"})

      assert Enum.any?(Governance.list_cap_table_entries(company.id), &(&1.id == ct.id))
      assert Governance.get_cap_table_entry!(ct.id).id == ct.id

      {:ok, updated} = Governance.update_cap_table_entry(ct, %{round_name: "Series A"})
      assert updated.round_name == "Series A"

      {:ok, _} = Governance.delete_cap_table_entry(updated)
    end

    test "list_cap_table_entries/0 returns all" do
      company = company_fixture()
      {:ok, ct} = Governance.create_cap_table_entry(%{company_id: company.id, investor: "Inv1", round_name: "Seed"})
      entries = Governance.list_cap_table_entries()
      assert Enum.any?(entries, &(&1.id == ct.id))
    end

    test "list_cap_table_entries/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_cap_table_entry(%{company_id: company1.id, investor: "A"})
      Governance.create_cap_table_entry(%{company_id: company2.id, investor: "B"})

      entries = Governance.list_cap_table_entries(company1.id)
      assert Enum.all?(entries, &(&1.company_id == company1.id))
    end

    test "get_cap_table_entry!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_cap_table_entry!(-1)
      end
    end
  end

  # ── Shareholder Resolutions ───────────────────────────

  describe "shareholder_resolutions" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, sr} = Governance.create_shareholder_resolution(%{company_id: company.id, title: "Approve merger", date: "2024-06-01"})

      assert Enum.any?(Governance.list_shareholder_resolutions(company.id), &(&1.id == sr.id))
      assert Governance.get_shareholder_resolution!(sr.id).id == sr.id

      {:ok, updated} = Governance.update_shareholder_resolution(sr, %{passed: true})
      assert updated.passed == true

      {:ok, _} = Governance.delete_shareholder_resolution(updated)
    end

    test "list_shareholder_resolutions/0 returns all" do
      company = company_fixture()
      Governance.create_shareholder_resolution(%{company_id: company.id, title: "Test", date: "2024-01-01"})
      assert length(Governance.list_shareholder_resolutions()) >= 1
    end

    test "list_shareholder_resolutions/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_shareholder_resolution(%{company_id: company1.id, title: "A", date: "2024-01-01"})
      Governance.create_shareholder_resolution(%{company_id: company2.id, title: "B", date: "2024-01-01"})

      resolutions = Governance.list_shareholder_resolutions(company1.id)
      assert Enum.all?(resolutions, &(&1.company_id == company1.id))
    end

    test "get_shareholder_resolution!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_shareholder_resolution!(-1)
      end
    end
  end

  # ── Powers of Attorney ────────────────────────────────

  describe "powers_of_attorney" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, poa} = Governance.create_power_of_attorney(%{company_id: company.id, grantor: "CEO", grantee: "VP"})

      assert Enum.any?(Governance.list_powers_of_attorney(company.id), &(&1.id == poa.id))
      assert Governance.get_power_of_attorney!(poa.id).id == poa.id

      {:ok, updated} = Governance.update_power_of_attorney(poa, %{grantee: "CFO"})
      assert updated.grantee == "CFO"

      {:ok, _} = Governance.delete_power_of_attorney(updated)
    end

    test "list_powers_of_attorney/0 returns all" do
      company = company_fixture()
      Governance.create_power_of_attorney(%{company_id: company.id, grantor: "CEO", grantee: "VP"})
      assert length(Governance.list_powers_of_attorney()) >= 1
    end

    test "list_powers_of_attorney/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_power_of_attorney(%{company_id: company1.id, grantor: "CEO", grantee: "VP"})
      Governance.create_power_of_attorney(%{company_id: company2.id, grantor: "CEO", grantee: "VP"})

      poas = Governance.list_powers_of_attorney(company1.id)
      assert Enum.all?(poas, &(&1.company_id == company1.id))
    end

    test "get_power_of_attorney!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_power_of_attorney!(-1)
      end
    end
  end

  # ── Equity Incentive Plans ────────────────────────────

  describe "equity_incentive_plans" do
    test "plans CRUD" do
      company = company_fixture()
      {:ok, eip} = Governance.create_equity_incentive_plan(%{company_id: company.id, plan_name: "2024 ESOP"})

      assert Enum.any?(Governance.list_equity_incentive_plans(company.id), &(&1.id == eip.id))
      assert Governance.get_equity_incentive_plan!(eip.id).id == eip.id

      {:ok, updated} = Governance.update_equity_incentive_plan(eip, %{plan_name: "2025 ESOP"})
      assert updated.plan_name == "2025 ESOP"

      {:ok, _} = Governance.delete_equity_incentive_plan(updated)
    end

    test "list_equity_incentive_plans/0 returns all" do
      company = company_fixture()
      Governance.create_equity_incentive_plan(%{company_id: company.id, plan_name: "Test Plan"})
      assert length(Governance.list_equity_incentive_plans()) >= 1
    end

    test "list_equity_incentive_plans/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_equity_incentive_plan(%{company_id: company1.id, plan_name: "Plan A"})
      Governance.create_equity_incentive_plan(%{company_id: company2.id, plan_name: "Plan B"})

      plans = Governance.list_equity_incentive_plans(company1.id)
      assert Enum.all?(plans, &(&1.company_id == company1.id))
    end

    test "get_equity_incentive_plan!/1 preloads grants and company" do
      company = company_fixture()
      {:ok, eip} = Governance.create_equity_incentive_plan(%{company_id: company.id, plan_name: "Test"})
      Governance.create_equity_grant(%{plan_id: eip.id, recipient: "Alice", grant_date: "2024-01-01"})

      plan = Governance.get_equity_incentive_plan!(eip.id)
      assert plan.company.id == company.id
      assert length(plan.grants) == 1
    end

    test "get_equity_incentive_plan!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_equity_incentive_plan!(-1)
      end
    end
  end

  # ── Equity Grants ─────────────────────────────────────

  describe "equity_grants" do
    test "grants CRUD" do
      plan = equity_incentive_plan_fixture()
      {:ok, eg} = Governance.create_equity_grant(%{plan_id: plan.id, recipient: "Alice", grant_date: "2024-01-01", quantity: 1000})

      assert Enum.any?(Governance.list_equity_grants(plan.id), &(&1.id == eg.id))
      assert Governance.get_equity_grant!(eg.id).id == eg.id

      {:ok, updated} = Governance.update_equity_grant(eg, %{quantity: 2000})
      assert updated.quantity == 2000

      {:ok, _} = Governance.delete_equity_grant(updated)
    end

    test "list_equity_grants/0 returns all" do
      plan = equity_incentive_plan_fixture()
      Governance.create_equity_grant(%{plan_id: plan.id, recipient: "Bob", grant_date: "2024-01-01"})
      assert length(Governance.list_equity_grants()) >= 1
    end

    test "list_equity_grants/1 filters by plan_id" do
      plan1 = equity_incentive_plan_fixture()
      plan2 = equity_incentive_plan_fixture()
      Governance.create_equity_grant(%{plan_id: plan1.id, recipient: "Alice", grant_date: "2024-01-01"})
      Governance.create_equity_grant(%{plan_id: plan2.id, recipient: "Bob", grant_date: "2024-01-01"})

      grants = Governance.list_equity_grants(plan1.id)
      assert Enum.all?(grants, &(&1.plan_id == plan1.id))
    end

    test "get_equity_grant!/1 preloads plan" do
      plan = equity_incentive_plan_fixture()
      {:ok, eg} = Governance.create_equity_grant(%{plan_id: plan.id, recipient: "Alice", grant_date: "2024-01-01"})
      grant = Governance.get_equity_grant!(eg.id)
      assert grant.plan.id == plan.id
    end

    test "get_equity_grant!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_equity_grant!(-1)
      end
    end
  end

  # ── Deals ─────────────────────────────────────────────

  describe "deals" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, d} = Governance.create_deal(%{company_id: company.id, counterparty: "Target Inc"})

      assert Enum.any?(Governance.list_deals(company.id), &(&1.id == d.id))
      assert Governance.get_deal!(d.id).id == d.id

      {:ok, updated} = Governance.update_deal(d, %{status: "closed"})
      assert updated.status == "closed"

      {:ok, _} = Governance.delete_deal(updated)
    end

    test "list_deals/0 returns all" do
      company = company_fixture()
      Governance.create_deal(%{company_id: company.id, counterparty: "Test"})
      assert length(Governance.list_deals()) >= 1
    end

    test "list_deals/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_deal(%{company_id: company1.id, counterparty: "A"})
      Governance.create_deal(%{company_id: company2.id, counterparty: "B"})

      deals = Governance.list_deals(company1.id)
      assert Enum.all?(deals, &(&1.company_id == company1.id))
    end

    test "get_deal!/1 preloads company" do
      company = company_fixture()
      {:ok, d} = Governance.create_deal(%{company_id: company.id, counterparty: "T"})
      deal = Governance.get_deal!(d.id)
      assert deal.company.id == company.id
    end

    test "get_deal!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_deal!(-1)
      end
    end
  end

  # ── Joint Ventures ────────────────────────────────────

  describe "joint_ventures" do
    test "CRUD operations" do
      company = company_fixture()
      {:ok, jv} = Governance.create_joint_venture(%{company_id: company.id, partner: "Partner Co", name: "JV Alpha"})

      assert Enum.any?(Governance.list_joint_ventures(company.id), &(&1.id == jv.id))
      assert Governance.get_joint_venture!(jv.id).id == jv.id

      {:ok, updated} = Governance.update_joint_venture(jv, %{name: "JV Beta"})
      assert updated.name == "JV Beta"

      {:ok, _} = Governance.delete_joint_venture(updated)
    end

    test "list_joint_ventures/0 returns all" do
      company = company_fixture()
      Governance.create_joint_venture(%{company_id: company.id, partner: "P", name: "JV1"})
      assert length(Governance.list_joint_ventures()) >= 1
    end

    test "list_joint_ventures/1 filters by company_id" do
      company1 = company_fixture()
      company2 = company_fixture()
      Governance.create_joint_venture(%{company_id: company1.id, partner: "A", name: "JV A"})
      Governance.create_joint_venture(%{company_id: company2.id, partner: "B", name: "JV B"})

      jvs = Governance.list_joint_ventures(company1.id)
      assert Enum.all?(jvs, &(&1.company_id == company1.id))
    end

    test "get_joint_venture!/1 preloads company" do
      company = company_fixture()
      {:ok, jv} = Governance.create_joint_venture(%{company_id: company.id, partner: "P", name: "JV"})
      fetched = Governance.get_joint_venture!(jv.id)
      assert fetched.company.id == company.id
    end

    test "get_joint_venture!/1 raises for non-existent" do
      assert_raise Ecto.NoResultsError, fn ->
        Governance.get_joint_venture!(-1)
      end
    end
  end

  # ── Investor Access ───────────────────────────────────
  # NOTE: investor_accesses table may not exist in all test environments.
  # These tests are skipped if the migration hasn't been run.

  # ── PubSub ────────────────────────────────────────────

  describe "subscribe/0" do
    test "subscribes to governance topic" do
      assert :ok == Governance.subscribe()
    end
  end

  # ── audit_and_broadcast ────────────────────────────────

  describe "audit_and_broadcast" do
    test "broadcasts on create" do
      Governance.subscribe()
      company = company_fixture()
      {:ok, bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-11-01"})
      assert_receive {:board_meetings_created, ^bm}
    end

    test "broadcasts on update" do
      company = company_fixture()
      {:ok, bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-11-01"})
      Governance.subscribe()
      {:ok, updated} = Governance.update_board_meeting(bm, %{status: "cancelled"})
      assert_receive {:board_meetings_updated, ^updated}
    end

    test "broadcasts on delete" do
      company = company_fixture()
      {:ok, bm} = Governance.create_board_meeting(%{company_id: company.id, scheduled_date: "2024-11-01"})
      Governance.subscribe()
      {:ok, deleted} = Governance.delete_board_meeting(bm)
      assert_receive {:board_meetings_deleted, ^deleted}
    end
  end
end
