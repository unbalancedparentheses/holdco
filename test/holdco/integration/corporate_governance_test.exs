defmodule Holdco.Integration.CorporateGovernanceTest do
  @moduledoc """
  Integration tests for corporate governance workflows:
  entity creation -> register entries -> board meetings -> resolutions ->
  signature workflows -> shareholder communications -> equity plans ->
  conflict of interest -> family governance.
  """
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Corporate
  alias Holdco.Governance
  alias Holdco.Documents

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_holding_company do
    {:ok, parent} = Corporate.create_company(%{name: "Global Holdings Corp", country: "US"})
    {:ok, sub1} = Corporate.create_company(%{name: "US Operations LLC", country: "US", parent_id: parent.id})
    {:ok, sub2} = Corporate.create_company(%{name: "EU Operations GmbH", country: "DE", parent_id: parent.id})
    %{parent: parent, us_sub: sub1, eu_sub: sub2}
  end

  # ===========================================================================
  # 1. Entity Creation and Corporate Structure
  # ===========================================================================

  describe "corporate structure" do
    test "create parent-subsidiary hierarchy and verify tree" do
      %{parent: parent, us_sub: us_sub, eu_sub: eu_sub} = setup_holding_company()

      loaded = Corporate.get_company!(parent.id)
      assert length(loaded.subsidiaries) == 2

      us = Corporate.get_company!(us_sub.id)
      assert us.parent_id == parent.id

      eu = Corporate.get_company!(eu_sub.id)
      assert eu.parent_id == parent.id

      tree = Corporate.company_tree()
      assert is_list(tree)
      root = Enum.find(tree, &(&1.company.id == parent.id))
      assert root != nil
      assert length(root.children) == 2
    end

    test "entity lifecycle events tracked from incorporation to active" do
      company = company_fixture(%{name: "New Entity Ltd"})

      {:ok, _incorporation} =
        Corporate.create_entity_lifecycle(%{
          company_id: company.id,
          event_type: "incorporation",
          event_date: "2025-01-15",
          description: "Entity incorporated in Delaware"
        })

      {:ok, _registered} =
        Corporate.create_entity_lifecycle(%{
          company_id: company.id,
          event_type: "registration",
          event_date: "2025-01-20",
          description: "Registered with Secretary of State"
        })

      {:ok, _active} =
        Corporate.create_entity_lifecycle(%{
          company_id: company.id,
          event_type: "other",
          event_date: "2025-02-01",
          description: "Entity operational"
        })

      timeline = Corporate.entity_timeline(company.id)
      assert length(timeline) == 3
    end

    test "beneficial owners and key personnel assigned to company" do
      company = company_fixture(%{name: "Governed Corp"})

      {:ok, _bo1} = Corporate.create_beneficial_owner(%{company_id: company.id, name: "Jane Smith"})
      {:ok, _bo2} = Corporate.create_beneficial_owner(%{company_id: company.id, name: "John Doe"})
      {:ok, _ceo} = Corporate.create_key_personnel(%{company_id: company.id, name: "Alice Johnson", title: "CEO"})
      {:ok, _cfo} = Corporate.create_key_personnel(%{company_id: company.id, name: "Bob Brown", title: "CFO"})

      owners = Corporate.list_beneficial_owners(company.id)
      assert length(owners) == 2

      personnel = Corporate.list_key_personnel(company.id)
      assert length(personnel) == 2
    end
  end

  # ===========================================================================
  # 2. Register Entries
  # ===========================================================================

  describe "register entries" do
    test "statutory registers: shareholders, directors, beneficial_owners" do
      company = company_fixture(%{name: "Registered Corp"})

      {:ok, _shareholder_entry} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "shareholders",
          entry_date: "2025-01-01",
          person_name: "Jane Smith",
          role_or_description: "Initial shareholder",
          status: "current"
        })

      {:ok, _director_entry} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "directors",
          entry_date: "2025-01-01",
          person_name: "Alice Johnson",
          role_or_description: "Director appointed",
          status: "current"
        })

      {:ok, _bo_entry} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "beneficial_owners",
          entry_date: "2025-06-15",
          person_name: "Bob",
          role_or_description: "UBO identified",
          status: "current"
        })

      entries = Corporate.list_register_entries(company.id)
      assert length(entries) == 3

      summary = Corporate.register_summary(company.id)
      assert summary["shareholders"] == 1
      assert summary["directors"] == 1
      assert summary["beneficial_owners"] == 1
    end

    test "current register filters by status" do
      company = company_fixture(%{name: "Register Test Corp"})

      {:ok, _current} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "directors",
          entry_date: "2025-01-01",
          person_name: "Current Director",
          status: "current"
        })

      {:ok, _historical} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "directors",
          entry_date: "2024-01-01",
          person_name: "Former Director",
          status: "historical"
        })

      current = Corporate.current_register(company.id, "directors")
      assert length(current) == 1
      assert hd(current).person_name == "Current Director"
    end
  end

  # ===========================================================================
  # 3. Board Meetings and Resolutions
  # ===========================================================================

  describe "board meetings and resolutions" do
    test "schedule meeting, pass resolution, document minutes" do
      company = company_fixture(%{name: "Board Corp"})

      {:ok, meeting} =
        Governance.create_board_meeting(%{
          company_id: company.id,
          scheduled_date: "2025-04-15",
          meeting_date: ~D[2025-04-15],
          title: "Q1 Board Meeting",
          location: "HQ Conference Room",
          status: "scheduled"
        })

      assert meeting.status == "scheduled"

      {:ok, resolution} =
        Governance.create_shareholder_resolution(%{
          company_id: company.id,
          title: "Approve Q1 Dividend",
          date: "2025-04-15",
          resolution_type: "ordinary",
          passed: true,
          votes_for: 85,
          votes_against: 15
        })

      assert resolution.passed == true

      {:ok, completed} = Governance.update_board_meeting(meeting, %{status: "completed"})
      assert completed.status == "completed"

      meetings = Governance.list_board_meetings(company.id)
      resolutions = Governance.list_shareholder_resolutions(company.id)
      assert length(meetings) >= 1
      assert length(resolutions) >= 1
    end

    test "upcoming meetings filtered correctly" do
      company = company_fixture(%{name: "Calendar Corp"})

      {:ok, _past} =
        Governance.create_board_meeting(%{
          company_id: company.id,
          scheduled_date: "2024-01-01",
          meeting_date: ~D[2024-01-01],
          status: "completed"
        })

      future_date = Date.add(Date.utc_today(), 30)

      {:ok, upcoming} =
        Governance.create_board_meeting(%{
          company_id: company.id,
          scheduled_date: Date.to_iso8601(future_date),
          meeting_date: future_date,
          status: "scheduled"
        })

      result = Governance.upcoming_meetings(company.id)
      assert Enum.any?(result, &(&1.id == upcoming.id))
    end
  end

  # ===========================================================================
  # 4. Signature Workflows
  # ===========================================================================

  describe "signature workflows" do
    test "create document, initiate signature workflow, sign, and complete" do
      company = company_fixture(%{name: "Signature Corp"})

      {:ok, doc} =
        Documents.create_document(%{
          company_id: company.id,
          name: "Board Resolution - Dividend Approval",
          doc_type: "resolution"
        })

      {:ok, workflow} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          document_id: doc.id,
          title: "Dividend Resolution Signatures",
          created_by: "compliance@acme.com",
          signers: [
            %{"email" => "ceo@acme.com", "name" => "CEO", "status" => "pending"},
            %{"email" => "cfo@acme.com", "name" => "CFO", "status" => "pending"}
          ],
          status: "pending_signatures",
          expiry_date: Date.add(Date.utc_today(), 30) |> Date.to_iso8601()
        })

      assert workflow.status == "pending_signatures"
      assert length(workflow.signers) == 2

      {:ok, partial} = Documents.sign_document(workflow.id, "ceo@acme.com")
      assert partial.status == "partially_signed"

      ceo_signer = Enum.find(partial.signers, &(&1["email"] == "ceo@acme.com"))
      assert ceo_signer["status"] == "signed"
      assert ceo_signer["signed_at"] != nil

      {:ok, completed} = Documents.sign_document(partial.id, "cfo@acme.com")
      assert completed.status == "completed"
    end

    test "pending_signatures lists only incomplete workflows" do
      company = company_fixture(%{name: "Pending Sig Corp"})

      {:ok, _pending} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Pending Workflow",
          status: "pending_signatures",
          signers: [%{"email" => "signer@test.com", "status" => "pending"}]
        })

      {:ok, _completed} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          title: "Completed Workflow",
          status: "completed",
          signers: [%{"email" => "signer@test.com", "status" => "signed"}]
        })

      pending = Documents.pending_signatures()
      assert Enum.any?(pending, &(&1.title == "Pending Workflow"))
      refute Enum.any?(pending, &(&1.title == "Completed Workflow"))
    end
  end

  # ===========================================================================
  # 5. Shareholder Communications
  # ===========================================================================

  describe "shareholder communications" do
    test "create, approve, and send shareholder communication" do
      company = company_fixture(%{name: "Comms Corp"})

      {:ok, comm} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          title: "Q1 2025 Investor Letter",
          communication_type: "annual_report",
          content: "Dear shareholders, Q1 was strong...",
          status: "draft"
        })

      assert comm.status == "draft"

      {:ok, approved} = Governance.update_shareholder_communication(comm, %{status: "approved"})
      assert approved.status == "approved"

      {:ok, sent} =
        Governance.update_shareholder_communication(approved, %{
          status: "sent",
          distribution_date: Date.utc_today()
        })

      assert sent.status == "sent"
    end

    test "pending communications lists only draft and approved" do
      company = company_fixture(%{name: "Pending Comms Corp"})

      {:ok, _draft} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          title: "Draft Letter",
          communication_type: "notice",
          status: "draft",
          distribution_date: Date.add(Date.utc_today(), 7)
        })

      {:ok, _sent} =
        Governance.create_shareholder_communication(%{
          company_id: company.id,
          title: "Sent Letter",
          communication_type: "notice",
          status: "sent"
        })

      pending = Governance.pending_communications(company.id)
      assert Enum.any?(pending, &(&1.title == "Draft Letter"))
      refute Enum.any?(pending, &(&1.title == "Sent Letter"))
    end

    test "communication summary counts by status" do
      company = company_fixture(%{name: "Summary Comms Corp"})

      {:ok, _} = Governance.create_shareholder_communication(%{company_id: company.id, title: "Draft 1", communication_type: "circular", status: "draft"})
      {:ok, _} = Governance.create_shareholder_communication(%{company_id: company.id, title: "Sent 1", communication_type: "circular", status: "sent"})
      {:ok, _} = Governance.create_shareholder_communication(%{company_id: company.id, title: "Sent 2", communication_type: "notice", status: "sent"})

      summary = Governance.communication_summary(company.id)
      assert summary["draft"] == 1
      assert summary["sent"] == 2
    end
  end

  # ===========================================================================
  # 6. Equity Plans and Grants
  # ===========================================================================

  describe "equity plans and grants" do
    test "create plan, issue grants, track vesting" do
      company = company_fixture(%{name: "Equity Corp"})

      {:ok, plan} =
        Governance.create_equity_incentive_plan(%{
          company_id: company.id,
          plan_name: "2025 Stock Option Plan"
        })

      {:ok, _grant1} =
        Governance.create_equity_grant(%{
          plan_id: plan.id,
          recipient: "CTO",
          grant_date: "2025-01-01"
        })

      {:ok, _grant2} =
        Governance.create_equity_grant(%{
          plan_id: plan.id,
          recipient: "VP Engineering",
          grant_date: "2025-03-01"
        })

      loaded = Governance.get_equity_incentive_plan!(plan.id)
      assert length(loaded.grants) == 2

      grants = Governance.list_equity_grants(plan.id)
      assert length(grants) == 2
    end
  end

  # ===========================================================================
  # 7. Conflict of Interest
  # ===========================================================================

  describe "conflict of interest" do
    test "declare, review, and resolve conflict" do
      company = company_fixture(%{name: "COI Corp"})

      {:ok, coi} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id,
          declarant_name: "Board Member X",
          declarant_role: "director",
          conflict_type: "financial",
          description: "Holds 5% stake in vendor company",
          declared_date: "2025-03-01",
          status: "declared"
        })

      assert coi.status == "declared"

      {:ok, reviewing} = Governance.update_conflict_of_interest(coi, %{status: "under_review"})
      assert reviewing.status == "under_review"

      {:ok, resolved} =
        Governance.update_conflict_of_interest(reviewing, %{
          status: "resolved",
          mitigation_plan: "Board member recused from vendor selection"
        })

      assert resolved.status == "resolved"
    end

    test "active conflicts summary" do
      company = company_fixture(%{name: "Active COI Corp"})

      {:ok, _active} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id,
          declarant_name: "Director A",
          declarant_role: "director",
          conflict_type: "financial",
          description: "Active conflict",
          declared_date: "2025-01-01",
          status: "declared"
        })

      {:ok, _resolved} =
        Governance.create_conflict_of_interest(%{
          company_id: company.id,
          declarant_name: "Director B",
          declarant_role: "officer",
          conflict_type: "personal",
          description: "Resolved conflict",
          declared_date: "2024-06-01",
          status: "resolved"
        })

      active = Governance.active_conflicts(company.id)
      assert Enum.any?(active, &(&1.declarant_name == "Director A"))
      refute Enum.any?(active, &(&1.declarant_name == "Director B"))
    end
  end

  # ===========================================================================
  # 8. Cross-Context: Corporate + Governance + Documents
  # ===========================================================================

  describe "cross-context corporate governance" do
    test "entity setup: company -> register -> board -> resolution -> document -> sign" do
      {:ok, company} = Corporate.create_company(%{name: "Full Governance Corp", country: "US"})

      {:ok, _} =
        Corporate.create_register_entry(%{
          company_id: company.id,
          register_type: "directors",
          entry_date: "2025-01-01",
          person_name: "Initial Directors",
          status: "current"
        })

      {:ok, meeting} =
        Governance.create_board_meeting(%{
          company_id: company.id,
          scheduled_date: "2025-03-15",
          title: "Inaugural Board Meeting",
          status: "scheduled"
        })

      {:ok, _resolution} =
        Governance.create_shareholder_resolution(%{
          company_id: company.id,
          title: "Adopt bylaws",
          date: "2025-03-15",
          passed: true
        })

      {:ok, doc} =
        Documents.create_document(%{
          company_id: company.id,
          name: "Board Meeting Minutes - March 2025",
          doc_type: "minutes"
        })

      {:ok, workflow} =
        Documents.create_signature_workflow(%{
          company_id: company.id,
          document_id: doc.id,
          title: "Minutes Approval",
          signers: [
            %{"email" => "chair@corp.com", "name" => "Chair", "status" => "pending"},
            %{"email" => "secretary@corp.com", "name" => "Secretary", "status" => "pending"}
          ],
          status: "pending_signatures"
        })

      {:ok, _} = Documents.sign_document(workflow.id, "chair@corp.com")
      {:ok, signed} = Documents.sign_document(workflow.id, "secretary@corp.com")
      assert signed.status == "completed"

      {:ok, done} = Governance.update_board_meeting(meeting, %{status: "completed"})
      assert done.status == "completed"
    end

    test "share classes and cap table tracked for company" do
      company = company_fixture(%{name: "Cap Table Corp"})

      {:ok, _common} =
        Corporate.create_share_class(%{
          company_id: company.id,
          class_code: "COM",
          name: "Common",
          shares_authorized: 10_000_000,
          shares_outstanding: 5_000_000,
          par_value: 0.01
        })

      {:ok, _preferred} =
        Corporate.create_share_class(%{
          company_id: company.id,
          class_code: "PFD-A",
          name: "Series A Preferred",
          shares_authorized: 2_000_000,
          shares_outstanding: 1_000_000,
          par_value: 1.0
        })

      cap_table = Corporate.cap_table(company.id)
      assert length(cap_table) == 2

      common = Enum.find(cap_table, &(&1.share_class.class_code == "COM"))
      assert Decimal.gt?(common.ownership_pct, Decimal.new("80"))
    end

    test "data room with documents for due diligence" do
      company = company_fixture(%{name: "Data Room Corp"})
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, doc1} = Documents.create_document(%{company_id: company.id, name: "Financial Statements 2024", doc_type: "financial"})
      {:ok, doc2} = Documents.create_document(%{company_id: company.id, name: "Articles of Incorporation", doc_type: "legal"})

      {:ok, room} =
        Documents.create_data_room(%{
          company_id: company.id,
          name: "Series B Due Diligence",
          created_by_id: user.id,
          status: "active"
        })

      {:ok, _} = Documents.add_document_to_room(%{data_room_id: room.id, document_id: doc1.id, added_by_id: user.id, sort_order: 1})
      {:ok, _} = Documents.add_document_to_room(%{data_room_id: room.id, document_id: doc2.id, added_by_id: user.id, sort_order: 2})

      room_docs = Documents.list_room_documents(room.id)
      assert length(room_docs) == 2
    end
  end

  # ===========================================================================
  # 9. Family Governance
  # ===========================================================================

  describe "family governance" do
    test "create family charter with members, estate plan, and succession plan" do
      company = company_fixture(%{name: "Family Office"})

      {:ok, charter} =
        Governance.create_family_charter(%{
          family_name: "Smith Family",
          version: "1.0",
          mission_statement: "Preserve wealth across generations",
          governance_structure: "Family Council",
          decision_making_rules: "Majority vote of voting members"
        })

      {:ok, _gen1} =
        Governance.create_family_member(%{
          family_charter_id: charter.id,
          full_name: "Robert Smith Sr.",
          relationship: "founder",
          generation: 1,
          role: "patriarch",
          voting_rights: true
        })

      {:ok, _gen2a} =
        Governance.create_family_member(%{
          family_charter_id: charter.id,
          full_name: "Robert Smith Jr.",
          relationship: "son",
          generation: 2,
          role: "member",
          voting_rights: true
        })

      {:ok, _gen2b} =
        Governance.create_family_member(%{
          family_charter_id: charter.id,
          full_name: "Sarah Smith",
          relationship: "daughter",
          generation: 2,
          role: "member",
          voting_rights: true
        })

      {:ok, _estate} =
        Governance.create_estate_plan(%{
          family_charter_id: charter.id,
          plan_name: "Robert Sr. Estate Plan",
          plan_type: "trust",
          principal_name: "Robert Smith Sr.",
          status: "executed",
          estimated_estate_value: 50_000_000.0
        })

      {:ok, _succession} =
        Governance.create_succession_plan(%{
          company_id: company.id,
          position_title: "CEO",
          current_holder: "Robert Smith Sr.",
          primary_successor: "Robert Smith Jr.",
          status: "active"
        })

      members = Governance.list_family_members(charter.id)
      assert length(members) == 3

      voting = Governance.voting_members(charter.id)
      assert length(voting) == 3

      by_gen = Governance.members_by_generation(charter.id)
      assert length(by_gen[1]) == 1
      assert length(by_gen[2]) == 2
    end
  end
end
