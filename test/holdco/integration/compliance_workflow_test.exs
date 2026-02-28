defmodule Holdco.Integration.ComplianceWorkflowTest do
  @moduledoc """
  Integration tests for compliance workflows:
  KYC onboarding -> AML screening -> sanctions checks -> regulatory filings ->
  ESG reporting -> emissions tracking -> regulatory change impact analysis ->
  BCP planning -> litigation management.
  """
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance
  alias Holdco.Corporate

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_regulated_company do
    company_fixture(%{name: "Regulated Holdings LLC", country: "US"})
  end

  # ===========================================================================
  # 1. KYC Onboarding Workflow
  # ===========================================================================

  describe "KYC onboarding workflow" do
    test "full KYC lifecycle: not_started -> documents_requested -> under_review -> verified" do
      company = setup_regulated_company()

      {:ok, kyc} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "New Investor Corp",
          entity_type: "corporate",
          risk_level: "medium",
          verification_status: "not_started",
          country_of_residence: "US"
        })

      assert kyc.verification_status == "not_started"

      # Request documents
      {:ok, requested} =
        Compliance.update_kyc_record(kyc, %{
          verification_status: "documents_requested",
          id_type: "corporate_registration",
          id_number: "EIN-12-3456789"
        })

      assert requested.verification_status == "documents_requested"

      # Under review
      {:ok, reviewing} =
        Compliance.update_kyc_record(requested, %{
          verification_status: "under_review",
          reviewer_notes: "Documents received, verifying with registry"
        })

      assert reviewing.verification_status == "under_review"

      # Verified
      {:ok, verified} =
        Compliance.update_kyc_record(reviewing, %{
          verification_status: "verified",
          last_review_date: "2025-03-01",
          next_review_date: "2026-03-01"
        })

      assert verified.verification_status == "verified"
      assert verified.next_review_date == ~D[2026-03-01]
    end

    test "KYC for PEP (politically exposed person) escalates risk level" do
      company = setup_regulated_company()

      {:ok, kyc} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Foreign Official",
          entity_type: "individual",
          risk_level: "low",
          pep_status: false
        })

      # Discovery of PEP status triggers risk escalation
      {:ok, pep_kyc} =
        Compliance.update_kyc_record(kyc, %{
          pep_status: true,
          risk_level: "pep",
          reviewer_notes: "Identified as PEP - enhanced due diligence required"
        })

      assert pep_kyc.pep_status == true
      assert pep_kyc.risk_level == "pep"
    end

    test "KYC due_for_review identifies records needing re-verification" do
      company = setup_regulated_company()

      {:ok, _expired} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Stale Investor",
          entity_type: "individual",
          verification_status: "verified",
          next_review_date: Date.add(Date.utc_today(), -30)
        })

      {:ok, _current} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Fresh Investor",
          entity_type: "individual",
          verification_status: "verified",
          next_review_date: Date.add(Date.utc_today(), 180)
        })

      due = Compliance.kyc_due_for_review()
      assert Enum.any?(due, &(&1.entity_name == "Stale Investor"))
      refute Enum.any?(due, &(&1.entity_name == "Fresh Investor"))
    end

    test "KYC summary aggregates by status and risk level" do
      company = setup_regulated_company()

      {:ok, _} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "A",
          entity_type: "individual",
          verification_status: "verified",
          risk_level: "low"
        })

      {:ok, _} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "B",
          entity_type: "corporate",
          verification_status: "under_review",
          risk_level: "high"
        })

      summary = Compliance.kyc_summary()
      assert is_list(summary.by_status)
      assert is_list(summary.by_risk)
    end

    test "all entity types supported for KYC" do
      company = setup_regulated_company()

      for etype <- ~w(individual corporate trust fund) do
        {:ok, kyc} =
          Compliance.create_kyc_record(%{
            company_id: company.id,
            entity_name: "Entity #{etype}",
            entity_type: etype
          })

        assert kyc.entity_type == etype
      end
    end
  end

  # ===========================================================================
  # 2. AML Screening Workflow
  # ===========================================================================

  describe "AML screening workflow" do
    test "create AML alert, investigate, and resolve" do
      company = setup_regulated_company()

      {:ok, alert} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "large_transaction",
          severity: "high",
          amount: 500_000.0,
          description: "Transaction exceeds $10K threshold",
          rule_triggered: "CTR threshold",
          status: "open"
        })

      assert alert.status == "open"

      # Assign investigator
      {:ok, investigating} =
        Compliance.update_aml_alert(alert, %{
          status: "investigating",
          assigned_to: "compliance_officer@acme.com"
        })

      assert investigating.status == "investigating"

      # Escalate
      {:ok, escalated} =
        Compliance.update_aml_alert(investigating, %{status: "escalated"})

      assert escalated.status == "escalated"

      # File SAR (Suspicious Activity Report)
      {:ok, filed} =
        Compliance.update_aml_alert(escalated, %{
          status: "filed_sar",
          resolution_notes: "SAR filed with FinCEN reference #12345",
          resolved_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      assert filed.status == "filed_sar"
      assert filed.resolved_at != nil
    end

    test "open_aml_alerts filters to active alerts only" do
      company = setup_regulated_company()

      {:ok, _open} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "velocity",
          severity: "medium",
          status: "open"
        })

      {:ok, _dismissed} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "structuring",
          severity: "low",
          status: "dismissed"
        })

      open = Compliance.open_aml_alerts()
      assert Enum.all?(open, &(&1.status in ["open", "investigating", "escalated"]))
    end

    test "AML alert summary groups by status, severity, and type" do
      company = setup_regulated_company()

      {:ok, _} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "large_transaction",
          severity: "high",
          status: "open"
        })

      {:ok, _} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "pattern_match",
          severity: "critical",
          status: "investigating"
        })

      summary = Compliance.aml_alert_summary()
      assert is_list(summary.by_status)
      assert is_list(summary.by_severity)
      assert is_list(summary.by_type)
    end
  end

  # ===========================================================================
  # 3. Sanctions Screening
  # ===========================================================================

  describe "sanctions screening workflow" do
    test "create sanctions list, add entries, and screen a name" do
      company = setup_regulated_company()

      # Create sanctions list
      {:ok, slist} =
        Compliance.create_sanctions_list(%{
          name: "OFAC SDN List",
          list_type: "SDN"
        })

      # Add sanctioned entity
      {:ok, entry} =
        Compliance.create_sanctions_entry(%{
          sanctions_list_id: slist.id,
          name: "Sanctioned Corp LLC"
        })

      # Clear check
      {:ok, clear_check} =
        Compliance.create_sanctions_check(%{
          company_id: company.id,
          checked_name: "Clean Company Inc",
          status: "clear"
        })

      assert clear_check.status == "clear"

      # Matched check
      {:ok, matched_check} =
        Compliance.create_sanctions_check(%{
          company_id: company.id,
          checked_name: "Sanctioned Corp LLC",
          status: "matched",
          matched_entry_id: entry.id,
          notes: "Name matches OFAC SDN entry"
        })

      assert matched_check.status == "matched"
      assert matched_check.matched_entry_id == entry.id
    end

    test "KYC -> sanctions check -> AML alert pipeline" do
      company = setup_regulated_company()

      # Step 1: KYC record
      {:ok, kyc} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: "Suspicious Corp",
          entity_type: "corporate",
          risk_level: "high"
        })

      # Step 2: Sanctions check
      {:ok, _check} =
        Compliance.create_sanctions_check(%{
          company_id: company.id,
          checked_name: kyc.entity_name,
          status: "clear"
        })

      # Step 3: Update KYC
      {:ok, updated_kyc} =
        Compliance.update_kyc_record(kyc, %{sanctions_checked: true})

      assert updated_kyc.sanctions_checked == true

      # Step 4: Later, a pattern triggers an AML alert
      {:ok, alert} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "geographic_risk",
          severity: "high",
          description: "Entity linked to high-risk jurisdiction after initial clearing"
        })

      assert alert.alert_type == "geographic_risk"
    end
  end

  # ===========================================================================
  # 4. Regulatory Compliance Workflow
  # ===========================================================================

  describe "regulatory compliance workflow" do
    test "regulatory change tracking: monitoring -> assessment -> implementation" do
      {:ok, change} =
        Compliance.create_regulatory_change(%{
          title: "New Basel IV Requirements",
          jurisdiction: "EU",
          regulatory_body: "ECB",
          change_type: "new_regulation",
          effective_date: "2026-01-01",
          impact_assessment: "high",
          status: "monitoring",
          affected_entities: ["fund_mgmt", "banking"],
          action_items: [
            %{"task" => "Gap analysis", "due" => "2025-06-01", "status" => "pending"},
            %{"task" => "System updates", "due" => "2025-09-01", "status" => "pending"}
          ]
        })

      assert change.status == "monitoring"
      assert length(change.affected_entities) == 2

      {:ok, assessing} =
        Compliance.update_regulatory_change(change, %{status: "assessment"})

      assert assessing.status == "assessment"

      {:ok, implementing} =
        Compliance.update_regulatory_change(assessing, %{status: "implementation"})

      assert implementing.status == "implementation"

      {:ok, completed} =
        Compliance.update_regulatory_change(implementing, %{status: "completed"})

      assert completed.status == "completed"
    end

    test "pending_regulatory_changes returns non-completed changes" do
      {:ok, _pending} =
        Compliance.create_regulatory_change(%{
          title: "Pending Change",
          jurisdiction: "US",
          change_type: "amendment",
          status: "monitoring"
        })

      {:ok, _completed} =
        Compliance.create_regulatory_change(%{
          title: "Done Change",
          jurisdiction: "US",
          change_type: "guidance",
          status: "completed"
        })

      pending = Compliance.pending_regulatory_changes()
      assert Enum.any?(pending, &(&1.title == "Pending Change"))
      refute Enum.any?(pending, &(&1.title == "Done Change"))
    end

    test "high_impact_changes filters critical and high impact" do
      {:ok, _} =
        Compliance.create_regulatory_change(%{
          title: "Critical Change",
          jurisdiction: "US",
          change_type: "enforcement",
          impact_assessment: "critical"
        })

      {:ok, _} =
        Compliance.create_regulatory_change(%{
          title: "Low Change",
          jurisdiction: "US",
          change_type: "guidance",
          impact_assessment: "low"
        })

      high = Compliance.high_impact_changes()
      assert Enum.any?(high, &(&1.title == "Critical Change"))
      refute Enum.any?(high, &(&1.title == "Low Change"))
    end

    test "regulatory filing and license management" do
      company = setup_regulated_company()

      # Create regulatory license
      {:ok, license} =
        Compliance.create_regulatory_license(%{
          company_id: company.id,
          license_type: "broker-dealer",
          issuing_authority: "SEC",
          status: "active"
        })

      assert license.license_type == "broker-dealer"

      # Create regulatory filing
      {:ok, filing} =
        Compliance.create_regulatory_filing(%{
          company_id: company.id,
          jurisdiction: "US",
          filing_type: "10-K",
          due_date: "2025-03-31"
        })

      assert filing.filing_type == "10-K"

      # Both linked to same company
      filings = Compliance.list_regulatory_filings(company.id)
      licenses = Compliance.list_regulatory_licenses(company.id)
      assert length(filings) >= 1
      assert length(licenses) >= 1
    end
  end

  # ===========================================================================
  # 5. ESG Reporting Workflow
  # ===========================================================================

  describe "ESG reporting workflow" do
    test "ESG report lifecycle: create -> track emissions -> score -> publish" do
      company = setup_regulated_company()

      # Create ESG report
      {:ok, report} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "gri",
          reporting_period_start: "2025-01-01",
          reporting_period_end: "2025-12-31",
          title: "Annual ESG Report 2025",
          status: "draft"
        })

      assert report.status == "draft"

      # Track emissions data
      {:ok, scope1} =
        Compliance.create_emissions_record(%{
          company_id: company.id,
          reporting_year: 2025,
          scope: "scope_1",
          category: "energy",
          source_description: "Natural gas heating",
          quantity: 500.0,
          unit: "tonnes_co2e",
          co2_equivalent: 500.0,
          verification_status: "self_assessed"
        })

      {:ok, scope2} =
        Compliance.create_emissions_record(%{
          company_id: company.id,
          reporting_year: 2025,
          scope: "scope_2",
          category: "energy",
          source_description: "Purchased electricity",
          quantity: 200.0,
          unit: "tonnes_co2e",
          co2_equivalent: 200.0,
          verification_status: "self_assessed"
        })

      {:ok, scope3} =
        Compliance.create_emissions_record(%{
          company_id: company.id,
          reporting_year: 2025,
          scope: "scope_3",
          category: "supply_chain",
          source_description: "Upstream transport",
          quantity: 1000.0,
          unit: "tonnes_co2e",
          co2_equivalent: 1000.0,
          verification_status: "unverified"
        })

      # Verify emissions by scope
      by_scope = Compliance.emissions_by_scope(company.id)
      assert length(by_scope) == 3

      total = Compliance.total_emissions(company.id, 2025)
      assert Decimal.equal?(total.total_co2e, Decimal.from_float(1700.0))
      assert total.count == 3

      # Update report with score and publish
      {:ok, scored} =
        Compliance.update_esg_report(report, %{
          score: "78.5",
          metrics: %{
            "total_emissions" => "1700",
            "scope_1" => "500",
            "scope_2" => "200",
            "scope_3" => "1000"
          },
          status: "under_review"
        })

      {:ok, published} =
        Compliance.update_esg_report(scored, %{
          status: "published",
          published_date: "2026-02-01"
        })

      assert published.status == "published"
      assert published.published_date == ~D[2026-02-01]
    end

    test "ESG trend shows improvement over time" do
      company = setup_regulated_company()

      {:ok, _} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "sasb",
          reporting_period_start: "2023-01-01",
          reporting_period_end: "2023-12-31",
          title: "2023 Report",
          score: "70.0"
        })

      {:ok, _} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "sasb",
          reporting_period_start: "2024-01-01",
          reporting_period_end: "2024-12-31",
          title: "2024 Report",
          score: "80.0"
        })

      {:ok, _} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "sasb",
          reporting_period_start: "2025-01-01",
          reporting_period_end: "2025-12-31",
          title: "2025 Report",
          score: "90.0"
        })

      trend = Compliance.esg_trend(company.id)
      assert length(trend) == 3
      scores = Enum.map(trend, & &1.score)
      assert Decimal.lt?(Enum.at(scores, 0), Enum.at(scores, 2))
    end

    test "latest_esg_report returns most recent" do
      company = setup_regulated_company()

      {:ok, _} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "tcfd",
          reporting_period_start: "2024-01-01",
          reporting_period_end: "2024-12-31",
          title: "Old Report"
        })

      {:ok, new_report} =
        Compliance.create_esg_report(%{
          company_id: company.id,
          framework: "tcfd",
          reporting_period_start: "2025-01-01",
          reporting_period_end: "2025-12-31",
          title: "New Report"
        })

      latest = Compliance.latest_esg_report(company.id)
      assert latest.id == new_report.id
    end
  end

  # ===========================================================================
  # 6. BCP (Business Continuity Planning) Workflow
  # ===========================================================================

  describe "BCP plan workflow" do
    test "create BCP plan, approve, test, and update results" do
      company = setup_regulated_company()

      {:ok, plan} =
        Compliance.create_bcp_plan(%{
          company_id: company.id,
          plan_name: "Disaster Recovery Plan",
          plan_type: "disaster_recovery",
          version: "1.0",
          status: "draft",
          rto_hours: 4,
          rpo_hours: 1,
          critical_systems: ["trading_platform", "risk_engine", "settlement"],
          key_contacts: [
            %{"name" => "CTO", "phone" => "555-0001"},
            %{"name" => "COO", "phone" => "555-0002"}
          ]
        })

      assert plan.status == "draft"
      assert plan.test_result == "not_tested"

      # Approve
      {:ok, approved} =
        Compliance.update_bcp_plan(plan, %{
          status: "approved",
          approved_by: "CEO",
          approved_date: "2025-03-01"
        })

      assert approved.status == "approved"

      # Activate
      {:ok, active} =
        Compliance.update_bcp_plan(approved, %{status: "active"})

      assert active.status == "active"

      # Test the plan
      {:ok, tested} =
        Compliance.update_bcp_plan(active, %{
          last_tested_date: "2025-06-15",
          next_test_date: "2025-12-15",
          test_result: "passed"
        })

      assert tested.test_result == "passed"
      assert tested.next_test_date == ~D[2025-12-15]
    end

    test "active_bcp_plans filters correctly" do
      company = setup_regulated_company()

      {:ok, _active} =
        Compliance.create_bcp_plan(%{
          company_id: company.id,
          plan_name: "Active Plan",
          plan_type: "business_continuity",
          status: "active"
        })

      {:ok, _retired} =
        Compliance.create_bcp_plan(%{
          company_id: company.id,
          plan_name: "Retired Plan",
          plan_type: "pandemic",
          status: "retired"
        })

      active = Compliance.active_bcp_plans(company.id)
      assert Enum.any?(active, &(&1.plan_name == "Active Plan"))
      refute Enum.any?(active, &(&1.plan_name == "Retired Plan"))
    end
  end

  # ===========================================================================
  # 7. Litigation and Insurance Claims
  # ===========================================================================

  describe "litigation and insurance claims workflow" do
    test "create litigation, file insurance claim, resolve both" do
      company = setup_regulated_company()

      # Step 1: Create insurance policy
      {:ok, policy} =
        Compliance.create_insurance_policy(%{
          company_id: company.id,
          policy_type: "D&O",
          provider: "Lloyds"
        })

      # Step 2: Create litigation
      {:ok, litigation} =
        Compliance.create_litigation(%{
          company_id: company.id,
          case_name: "Smith v. Regulated Holdings",
          case_number: "2025-CV-001",
          jurisdiction: "US",
          status: "active",
          estimated_exposure: 500_000.0
        })

      assert litigation.status == "active"

      # Step 3: File insurance claim against the policy
      {:ok, claim} =
        Compliance.create_insurance_claim(%{
          company_id: company.id,
          policy_id: policy.id,
          claim_number: "CLM-2025-001",
          claimed_amount: 500_000.0,
          claim_date: "2025-06-01",
          status: "filed"
        })

      assert claim.status == "filed"

      # Step 4: Resolve litigation
      {:ok, settled} =
        Compliance.update_litigation(litigation, %{
          status: "settled",
          actual_outcome_amount: 300_000.0
        })

      assert settled.status == "settled"

      # Step 5: Update claim
      {:ok, paid_claim} =
        Compliance.update_insurance_claim(claim, %{
          status: "settled",
          settled_amount: 300_000.0
        })

      assert paid_claim.status == "settled"
    end

    test "litigation exposure summarizes potential financial risk" do
      company = setup_regulated_company()

      {:ok, _} =
        Compliance.create_litigation(%{
          company_id: company.id,
          case_name: "Case A",
          jurisdiction: "US",
          status: "active",
          estimated_exposure: 1_000_000.0
        })

      {:ok, _} =
        Compliance.create_litigation(%{
          company_id: company.id,
          case_name: "Case B",
          jurisdiction: "UK",
          status: "active",
          estimated_exposure: 500_000.0
        })

      exposure = Compliance.litigation_exposure(company.id)
      assert Decimal.gt?(exposure, Decimal.new("0"))
    end
  end

  # ===========================================================================
  # 8. Cross-Context: Compliance + Corporate
  # ===========================================================================

  describe "compliance-corporate integration" do
    test "company onboarding triggers KYC, sanctions check, and compliance checklist" do
      # Step 1: Create company
      {:ok, company} =
        Corporate.create_company(%{name: "New Fund Vehicle LLC", country: "KY"})

      # Step 2: Register beneficial owners
      {:ok, bo} =
        Corporate.create_beneficial_owner(%{
          company_id: company.id,
          name: "John Smith"
        })

      # Step 3: KYC for the company and its owners
      {:ok, company_kyc} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: company.name,
          entity_type: "corporate",
          risk_level: "medium",
          country_of_residence: "KY"
        })

      {:ok, owner_kyc} =
        Compliance.create_kyc_record(%{
          company_id: company.id,
          entity_name: bo.name,
          entity_type: "individual",
          risk_level: "low"
        })

      # Step 4: Sanctions screen both
      {:ok, company_check} =
        Compliance.create_sanctions_check(%{
          company_id: company.id,
          checked_name: company.name,
          status: "clear"
        })

      {:ok, owner_check} =
        Compliance.create_sanctions_check(%{
          company_id: company.id,
          checked_name: bo.name,
          status: "clear"
        })

      # Step 5: Create compliance checklist
      {:ok, checklist} =
        Compliance.create_compliance_checklist(%{
          company_id: company.id,
          jurisdiction: "KY",
          item: "Annual KYC refresh"
        })

      # Verify everything is linked to the same company
      kyc_records = Compliance.list_kyc_records(company.id)
      assert length(kyc_records) == 2

      checks = Compliance.list_sanctions_checks(company.id)
      assert length(checks) >= 2

      checklists = Compliance.list_compliance_checklists(company.id)
      assert length(checklists) >= 1
    end

    test "annual filing due dates tracked alongside tax deadlines" do
      company = setup_regulated_company()

      {:ok, filing} =
        Compliance.create_annual_filing(%{
          company_id: company.id,
          jurisdiction: "US",
          filing_type: "annual_return",
          due_date: "2025-03-31"
        })

      {:ok, deadline} =
        Compliance.create_tax_deadline(%{
          company_id: company.id,
          jurisdiction: "US",
          description: "Federal income tax",
          due_date: "2025-04-15"
        })

      filings = Compliance.list_annual_filings(company.id)
      deadlines = Compliance.list_tax_deadlines(company.id)

      assert Enum.any?(filings, &(&1.id == filing.id))
      assert Enum.any?(deadlines, &(&1.id == deadline.id))
    end
  end

  # ===========================================================================
  # 9. Reporting Templates
  # ===========================================================================

  describe "reporting template workflow" do
    test "create template and generate BO register report" do
      # Setup a company with beneficial owners
      company = company_fixture(%{name: "Report Target LLC"})

      {:ok, _bo1} =
        Corporate.create_beneficial_owner(%{company_id: company.id, name: "Owner A"})

      {:ok, _bo2} =
        Corporate.create_beneficial_owner(%{company_id: company.id, name: "Owner B"})

      {:ok, template} =
        Compliance.create_reporting_template(%{
          name: "BO Register Report",
          template_type: "bo_register",
          jurisdiction: "KY"
        })

      {:ok, report} = Compliance.generate_report(template.id)

      assert report.type == "bo_register"
      assert report.jurisdiction == "KY"
      assert is_list(report.records)
      assert length(report.records) > 0
    end

    test "create and generate AML report template" do
      company = setup_regulated_company()

      {:ok, _alert} =
        Compliance.create_aml_alert(%{
          company_id: company.id,
          alert_type: "large_transaction",
          severity: "high"
        })

      {:ok, template} =
        Compliance.create_reporting_template(%{
          name: "AML Summary Report",
          template_type: "aml_report",
          jurisdiction: "US"
        })

      {:ok, report} = Compliance.generate_report(template.id)

      assert report.type == "aml_report"
      assert is_list(report.records)
    end
  end
end
