defmodule Holdco.SchemasChangesetTest do
  use Holdco.DataCase, async: true

  # ── 1. Compliance.EmissionsRecord ──────────────────────────────────────
  # required: [:company_id, :reporting_year, :scope, :category]
  # defaults: scope: "scope_1", category: "energy"

  describe "Compliance.EmissionsRecord" do
    alias Holdco.Compliance.EmissionsRecord

    @valid_attrs %{company_id: 1, reporting_year: 2024, scope: "scope_1", category: "energy"}

    test "valid changeset with required fields" do
      changeset = EmissionsRecord.changeset(%EmissionsRecord{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = EmissionsRecord.changeset(%EmissionsRecord{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).reporting_year
      # scope and category have defaults so they are not blank
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{scope: "invalid", category: "invalid", unit: "invalid", verification_status: "invalid"})
      changeset = EmissionsRecord.changeset(%EmissionsRecord{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).scope
      assert "is invalid" in errors_on(changeset).category
      assert "is invalid" in errors_on(changeset).unit
      assert "is invalid" in errors_on(changeset).verification_status
    end
  end

  # ── 2. Compliance.KycRecord ────────────────────────────────────────────
  # required: [:company_id, :entity_name, :entity_type]
  # defaults: entity_type: "individual"

  describe "Compliance.KycRecord" do
    alias Holdco.Compliance.KycRecord

    @valid_attrs %{company_id: 1, entity_name: "John Doe", entity_type: "individual"}

    test "valid changeset with required fields" do
      changeset = KycRecord.changeset(%KycRecord{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = KycRecord.changeset(%KycRecord{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).entity_name
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{entity_type: "invalid", risk_level: "invalid", verification_status: "invalid"})
      changeset = KycRecord.changeset(%KycRecord{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).entity_type
      assert "is invalid" in errors_on(changeset).risk_level
      assert "is invalid" in errors_on(changeset).verification_status
    end
  end

  # ── 3. Compliance.TransferPricingStudy ─────────────────────────────────
  # required: [:company_id, :study_name, :fiscal_year, :related_party_name]
  # no defaults on required fields

  describe "Compliance.TransferPricingStudy" do
    alias Holdco.Compliance.TransferPricingStudy

    @valid_attrs %{company_id: 1, study_name: "TP Study 2024", fiscal_year: 2024, related_party_name: "SubCo"}

    test "valid changeset with required fields" do
      changeset = TransferPricingStudy.changeset(%TransferPricingStudy{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = TransferPricingStudy.changeset(%TransferPricingStudy{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).study_name
      assert "can't be blank" in errors_on(changeset).fiscal_year
      assert "can't be blank" in errors_on(changeset).related_party_name
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{transaction_type: "invalid", method: "invalid", conclusion: "invalid", documentation_status: "invalid"})
      changeset = TransferPricingStudy.changeset(%TransferPricingStudy{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).transaction_type
      assert "is invalid" in errors_on(changeset).method
      assert "is invalid" in errors_on(changeset).conclusion
      assert "is invalid" in errors_on(changeset).documentation_status
    end
  end

  # ── 4. Governance.EthicsReport ─────────────────────────────────────────
  # required: [:company_id, :report_type, :reporter_type, :severity, :description, :reported_date]
  # defaults: report_type: "whistleblower", reporter_type: "anonymous", severity: "medium"

  describe "Governance.EthicsReport" do
    alias Holdco.Governance.EthicsReport

    @valid_attrs %{
      company_id: 1,
      report_type: "whistleblower",
      reporter_type: "anonymous",
      severity: "medium",
      description: "Something happened",
      reported_date: ~D[2024-01-15]
    }

    test "valid changeset with required fields" do
      changeset = EthicsReport.changeset(%EthicsReport{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = EthicsReport.changeset(%EthicsReport{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).reported_date
      # report_type, reporter_type, severity have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{report_type: "invalid", reporter_type: "invalid", severity: "invalid", status: "invalid"})
      changeset = EthicsReport.changeset(%EthicsReport{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).report_type
      assert "is invalid" in errors_on(changeset).reporter_type
      assert "is invalid" in errors_on(changeset).severity
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 5. Analytics.BiConnector ───────────────────────────────────────────
  # required: [:name, :connector_type]
  # no defaults on required fields

  describe "Analytics.BiConnector" do
    alias Holdco.Analytics.BiConnector

    @valid_attrs %{name: "My BI", connector_type: "power_bi"}

    test "valid changeset with required fields" do
      changeset = BiConnector.changeset(%BiConnector{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = BiConnector.changeset(%BiConnector{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).connector_type
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{connector_type: "invalid", refresh_frequency: "invalid", sync_status: "invalid"})
      changeset = BiConnector.changeset(%BiConnector{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).connector_type
      assert "is invalid" in errors_on(changeset).refresh_frequency
      assert "is invalid" in errors_on(changeset).sync_status
    end
  end

  # ── 7. Compliance.AmlAlert ────────────────────────────────────────────
  # required: [:company_id, :alert_type, :severity]
  # defaults: alert_type: "large_transaction", severity: "medium"

  describe "Compliance.AmlAlert" do
    alias Holdco.Compliance.AmlAlert

    @valid_attrs %{company_id: 1, alert_type: "large_transaction", severity: "medium"}

    test "valid changeset with required fields" do
      changeset = AmlAlert.changeset(%AmlAlert{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = AmlAlert.changeset(%AmlAlert{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      # alert_type and severity have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{alert_type: "invalid", severity: "invalid", status: "invalid"})
      changeset = AmlAlert.changeset(%AmlAlert{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).alert_type
      assert "is invalid" in errors_on(changeset).severity
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 8. Compliance.BcpPlan ─────────────────────────────────────────────
  # required: [:company_id, :plan_name, :plan_type]
  # defaults: plan_type: "business_continuity"

  describe "Compliance.BcpPlan" do
    alias Holdco.Compliance.BcpPlan

    @valid_attrs %{company_id: 1, plan_name: "DR Plan", plan_type: "disaster_recovery"}

    test "valid changeset with required fields" do
      changeset = BcpPlan.changeset(%BcpPlan{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = BcpPlan.changeset(%BcpPlan{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).plan_name
      # plan_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{plan_type: "invalid", status: "invalid", test_result: "invalid"})
      changeset = BcpPlan.changeset(%BcpPlan{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plan_type
      assert "is invalid" in errors_on(changeset).status
      assert "is invalid" in errors_on(changeset).test_result
    end
  end

  # ── 9. Compliance.Litigation ──────────────────────────────────────────
  # required: [:company_id, :case_name, :case_type, :party_role]
  # defaults: case_type: "civil", party_role: "defendant"

  describe "Compliance.Litigation" do
    alias Holdco.Compliance.Litigation

    @valid_attrs %{company_id: 1, case_name: "Doe v. Corp", case_type: "civil", party_role: "defendant"}

    test "valid changeset with required fields" do
      changeset = Litigation.changeset(%Litigation{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Litigation.changeset(%Litigation{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).case_name
      # case_type and party_role have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{case_type: "invalid", party_role: "invalid", status: "invalid"})
      changeset = Litigation.changeset(%Litigation{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).case_type
      assert "is invalid" in errors_on(changeset).party_role
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 10. Corporate.RelatedPartyTransaction ─────────────────────────────
  # required: [:company_id, :related_party_name, :relationship, :transaction_type, :transaction_date, :amount]
  # no defaults on required fields

  describe "Corporate.RelatedPartyTransaction" do
    alias Holdco.Corporate.RelatedPartyTransaction

    @valid_attrs %{
      company_id: 1,
      related_party_name: "SubCo",
      relationship: "subsidiary",
      transaction_type: "sale",
      transaction_date: ~D[2024-03-01],
      amount: Decimal.new("1000.00")
    }

    test "valid changeset with required fields" do
      changeset = RelatedPartyTransaction.changeset(%RelatedPartyTransaction{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = RelatedPartyTransaction.changeset(%RelatedPartyTransaction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).related_party_name
      assert "can't be blank" in errors_on(changeset).relationship
      assert "can't be blank" in errors_on(changeset).transaction_type
      assert "can't be blank" in errors_on(changeset).transaction_date
      assert "can't be blank" in errors_on(changeset).amount
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{relationship: "invalid", transaction_type: "invalid", disclosure_status: "invalid"})
      changeset = RelatedPartyTransaction.changeset(%RelatedPartyTransaction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).relationship
      assert "is invalid" in errors_on(changeset).transaction_type
      assert "is invalid" in errors_on(changeset).disclosure_status
    end
  end

  # ── 11. Finance.CompensationRecord ────────────────────────────────────
  # required: [:company_id, :employee_name, :compensation_type, :amount, :frequency]
  # defaults: compensation_type: "salary", frequency: "annual"

  describe "Finance.CompensationRecord" do
    alias Holdco.Finance.CompensationRecord

    @valid_attrs %{
      company_id: 1,
      employee_name: "Jane Doe",
      compensation_type: "salary",
      amount: Decimal.new("120000"),
      frequency: "annual"
    }

    test "valid changeset with required fields" do
      changeset = CompensationRecord.changeset(%CompensationRecord{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = CompensationRecord.changeset(%CompensationRecord{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).employee_name
      assert "can't be blank" in errors_on(changeset).amount
      # compensation_type and frequency have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{compensation_type: "invalid", frequency: "invalid", status: "invalid"})
      changeset = CompensationRecord.changeset(%CompensationRecord{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).compensation_type
      assert "is invalid" in errors_on(changeset).frequency
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 12. Finance.TrustAccount ──────────────────────────────────────────
  # required: [:company_id, :trust_name, :trust_type, :trustee_name]
  # defaults: trust_type: "revocable"

  describe "Finance.TrustAccount" do
    alias Holdco.Finance.TrustAccount

    @valid_attrs %{company_id: 1, trust_name: "Family Trust", trust_type: "revocable", trustee_name: "John Doe"}

    test "valid changeset with required fields" do
      changeset = TrustAccount.changeset(%TrustAccount{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = TrustAccount.changeset(%TrustAccount{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).trust_name
      assert "can't be blank" in errors_on(changeset).trustee_name
      # trust_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{trust_type: "invalid", status: "invalid", distribution_schedule: "invalid"})
      changeset = TrustAccount.changeset(%TrustAccount{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).trust_type
      assert "is invalid" in errors_on(changeset).status
      assert "is invalid" in errors_on(changeset).distribution_schedule
    end
  end

  # ── 13. Governance.ConflictOfInterest ─────────────────────────────────
  # required: [:company_id, :declarant_name, :declarant_role, :conflict_type, :description, :declared_date]
  # no defaults on required fields

  describe "Governance.ConflictOfInterest" do
    alias Holdco.Governance.ConflictOfInterest

    @valid_attrs %{
      company_id: 1,
      declarant_name: "Jane Smith",
      declarant_role: "director",
      conflict_type: "financial",
      description: "Board member has shares in vendor",
      declared_date: ~D[2024-02-01]
    }

    test "valid changeset with required fields" do
      changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).declarant_name
      assert "can't be blank" in errors_on(changeset).declarant_role
      assert "can't be blank" in errors_on(changeset).conflict_type
      assert "can't be blank" in errors_on(changeset).description
      assert "can't be blank" in errors_on(changeset).declared_date
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{declarant_role: "invalid", conflict_type: "invalid", status: "invalid"})
      changeset = ConflictOfInterest.changeset(%ConflictOfInterest{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).declarant_role
      assert "is invalid" in errors_on(changeset).conflict_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 14. Analytics.Airdrop ─────────────────────────────────────────────
  # required: [:company_id, :event_type, :token_name, :chain]
  # defaults: event_type: "airdrop", chain: "ethereum"

  describe "Analytics.Airdrop" do
    alias Holdco.Analytics.Airdrop

    @valid_attrs %{company_id: 1, event_type: "airdrop", token_name: "UNI", chain: "ethereum"}

    test "valid changeset with required fields" do
      changeset = Airdrop.changeset(%Airdrop{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Airdrop.changeset(%Airdrop{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).token_name
      # event_type and chain have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{event_type: "invalid", chain: "invalid"})
      changeset = Airdrop.changeset(%Airdrop{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).event_type
      assert "is invalid" in errors_on(changeset).chain
    end
  end

  # ── 15. Compliance.EsgReport ──────────────────────────────────────────
  # required: [:company_id, :framework, :reporting_period_start, :reporting_period_end, :title]
  # defaults: framework: "gri"

  describe "Compliance.EsgReport" do
    alias Holdco.Compliance.EsgReport

    @valid_attrs %{
      company_id: 1,
      framework: "gri",
      reporting_period_start: ~D[2024-01-01],
      reporting_period_end: ~D[2024-12-31],
      title: "Annual ESG Report"
    }

    test "valid changeset with required fields" do
      changeset = EsgReport.changeset(%EsgReport{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = EsgReport.changeset(%EsgReport{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).reporting_period_start
      assert "can't be blank" in errors_on(changeset).reporting_period_end
      assert "can't be blank" in errors_on(changeset).title
      # framework has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{framework: "invalid", status: "invalid"})
      changeset = EsgReport.changeset(%EsgReport{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).framework
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 16. Compliance.InsuranceClaim ─────────────────────────────────────
  # required: [:company_id, :claim_number, :claim_type]
  # defaults: claim_type: "other"

  describe "Compliance.InsuranceClaim" do
    alias Holdco.Compliance.InsuranceClaim

    @valid_attrs %{company_id: 1, claim_number: "CLM-001", claim_type: "property"}

    test "valid changeset with required fields" do
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).claim_number
      # claim_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{claim_type: "invalid", status: "invalid"})
      changeset = InsuranceClaim.changeset(%InsuranceClaim{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).claim_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 17. Compliance.RegulatoryCapital ──────────────────────────────────
  # required: [:company_id, :reporting_date, :framework]
  # defaults: framework: "basel_iii"

  describe "Compliance.RegulatoryCapital" do
    alias Holdco.Compliance.RegulatoryCapital

    @valid_attrs %{company_id: 1, reporting_date: ~D[2024-06-30], framework: "basel_iii"}

    test "valid changeset with required fields" do
      changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).reporting_date
      # framework has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{framework: "invalid", status: "invalid"})
      changeset = RegulatoryCapital.changeset(%RegulatoryCapital{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).framework
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 18. Compliance.ReportingTemplate ──────────────────────────────────
  # required: [:name, :template_type, :frequency]
  # defaults: template_type: "crs", frequency: "annual"

  describe "Compliance.ReportingTemplate" do
    alias Holdco.Compliance.ReportingTemplate

    @valid_attrs %{name: "CRS Template", template_type: "crs", frequency: "annual"}

    test "valid changeset with required fields" do
      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      # template_type and frequency have defaults
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{template_type: "invalid", frequency: "invalid"})
      changeset = ReportingTemplate.changeset(%ReportingTemplate{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).template_type
      assert "is invalid" in errors_on(changeset).frequency
    end
  end

  # ── 19. Corporate.Contract ────────────────────────────────────────────
  # required: [:company_id, :title, :counterparty, :contract_type]
  # defaults: contract_type: "other"

  describe "Corporate.Contract" do
    alias Holdco.Corporate.Contract

    @valid_attrs %{company_id: 1, title: "Service Agreement", counterparty: "Vendor Co", contract_type: "service"}

    test "valid changeset with required fields" do
      changeset = Contract.changeset(%Contract{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Contract.changeset(%Contract{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).counterparty
      # contract_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{contract_type: "invalid", status: "invalid"})
      changeset = Contract.changeset(%Contract{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).contract_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 20. Corporate.CorporateAction ─────────────────────────────────────
  # required: [:company_id, :action_type]
  # no defaults on required fields (action_type has no default)

  describe "Corporate.CorporateAction" do
    alias Holdco.Corporate.CorporateAction

    @valid_attrs %{company_id: 1, action_type: "stock_split"}

    test "valid changeset with required fields" do
      changeset = CorporateAction.changeset(%CorporateAction{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = CorporateAction.changeset(%CorporateAction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).action_type
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{action_type: "invalid", status: "invalid"})
      changeset = CorporateAction.changeset(%CorporateAction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 21. Corporate.EntityLifecycle ─────────────────────────────────────
  # required: [:company_id, :event_type, :event_date]
  # no defaults on required fields (event_date is a string field with validate_date_format)

  describe "Corporate.EntityLifecycle" do
    alias Holdco.Corporate.EntityLifecycle

    @valid_attrs %{company_id: 1, event_type: "incorporation", event_date: "2024-01-01"}

    test "valid changeset with required fields" do
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).event_type
      assert "can't be blank" in errors_on(changeset).event_date
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{event_type: "invalid", status: "invalid"})
      changeset = EntityLifecycle.changeset(%EntityLifecycle{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).event_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 22. Corporate.IpAsset ────────────────────────────────────────────
  # required: [:company_id, :name, :asset_type]
  # defaults: asset_type: "patent"

  describe "Corporate.IpAsset" do
    alias Holdco.Corporate.IpAsset

    @valid_attrs %{company_id: 1, name: "Logo TM", asset_type: "trademark"}

    test "valid changeset with required fields" do
      changeset = IpAsset.changeset(%IpAsset{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = IpAsset.changeset(%IpAsset{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).name
      # asset_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{asset_type: "invalid", status: "invalid"})
      changeset = IpAsset.changeset(%IpAsset{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).asset_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 23. Corporate.LeiRecord ──────────────────────────────────────────
  # required: [:company_id, :lei_code]
  # no defaults on required fields
  # also: validate_length(:lei_code, is: 20)

  describe "Corporate.LeiRecord" do
    alias Holdco.Corporate.LeiRecord

    @valid_attrs %{company_id: 1, lei_code: "52990099AAAAAABBCCDD"}

    test "valid changeset with required fields" do
      changeset = LeiRecord.changeset(%LeiRecord{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = LeiRecord.changeset(%LeiRecord{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).lei_code
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{registration_status: "invalid", entity_status: "invalid"})
      changeset = LeiRecord.changeset(%LeiRecord{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).registration_status
      assert "is invalid" in errors_on(changeset).entity_status
    end

    test "invalid changeset with wrong lei_code length" do
      attrs = %{company_id: 1, lei_code: "SHORT"}
      changeset = LeiRecord.changeset(%LeiRecord{}, attrs)
      refute changeset.valid?
      assert "should be 20 character(s)" in errors_on(changeset).lei_code
    end
  end

  # ── 24. Corporate.RegisterEntry ───────────────────────────────────────
  # required: [:company_id, :register_type, :entry_date]
  # no defaults on required fields (entry_date is a string with validate_date_format)

  describe "Corporate.RegisterEntry" do
    alias Holdco.Corporate.RegisterEntry

    @valid_attrs %{company_id: 1, register_type: "directors", entry_date: "2024-01-01"}

    test "valid changeset with required fields" do
      changeset = RegisterEntry.changeset(%RegisterEntry{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = RegisterEntry.changeset(%RegisterEntry{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).register_type
      assert "can't be blank" in errors_on(changeset).entry_date
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{register_type: "invalid", status: "invalid"})
      changeset = RegisterEntry.changeset(%RegisterEntry{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).register_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 25. Corporate.ShareClass ──────────────────────────────────────────
  # required: [:company_id, :name, :class_code]
  # no defaults on required fields

  describe "Corporate.ShareClass" do
    alias Holdco.Corporate.ShareClass

    @valid_attrs %{company_id: 1, name: "Common", class_code: "COM"}

    test "valid changeset with required fields" do
      changeset = ShareClass.changeset(%ShareClass{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ShareClass.changeset(%ShareClass{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).class_code
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{dividend_preference: "invalid", status: "invalid"})
      changeset = ShareClass.changeset(%ShareClass{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).dividend_preference
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 26. Documents.DataRoom ───────────────────────────────────────────
  # required: [:company_id, :name]
  # no defaults on required fields

  describe "Documents.DataRoom" do
    alias Holdco.Documents.DataRoom

    @valid_attrs %{company_id: 1, name: "Series A Data Room"}

    test "valid changeset with required fields" do
      changeset = DataRoom.changeset(%DataRoom{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = DataRoom.changeset(%DataRoom{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{access_level: "invalid", status: "invalid"})
      changeset = DataRoom.changeset(%DataRoom{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).access_level
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 27. Finance.BankGuarantee ─────────────────────────────────────────
  # required: [:company_id, :guarantee_type, :issuing_bank, :beneficiary, :amount]
  # defaults: guarantee_type: "performance"

  describe "Finance.BankGuarantee" do
    alias Holdco.Finance.BankGuarantee

    @valid_attrs %{
      company_id: 1,
      guarantee_type: "performance",
      issuing_bank: "HSBC",
      beneficiary: "Client Co",
      amount: Decimal.new("500000")
    }

    test "valid changeset with required fields" do
      changeset = BankGuarantee.changeset(%BankGuarantee{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = BankGuarantee.changeset(%BankGuarantee{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).issuing_bank
      assert "can't be blank" in errors_on(changeset).beneficiary
      assert "can't be blank" in errors_on(changeset).amount
      # guarantee_type has default
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{guarantee_type: "invalid", status: "invalid"})
      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).guarantee_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 28. Finance.CharitableGift ────────────────────────────────────────
  # required: [:company_id, :recipient_name, :amount, :gift_date]
  # no defaults on required fields

  describe "Finance.CharitableGift" do
    alias Holdco.Finance.CharitableGift

    @valid_attrs %{
      company_id: 1,
      recipient_name: "Red Cross",
      amount: Decimal.new("10000"),
      gift_date: ~D[2024-06-15]
    }

    test "valid changeset with required fields" do
      changeset = CharitableGift.changeset(%CharitableGift{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = CharitableGift.changeset(%CharitableGift{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).recipient_name
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).gift_date
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{recipient_type: "invalid", gift_type: "invalid"})
      changeset = CharitableGift.changeset(%CharitableGift{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).recipient_type
      assert "is invalid" in errors_on(changeset).gift_type
    end
  end

  # ── 29. Finance.TrustTransaction ──────────────────────────────────────
  # required: [:trust_account_id, :transaction_type, :amount, :transaction_date]
  # no defaults on required fields

  describe "Finance.TrustTransaction" do
    alias Holdco.Finance.TrustTransaction

    @valid_attrs %{
      trust_account_id: 1,
      transaction_type: "contribution",
      amount: Decimal.new("50000"),
      transaction_date: ~D[2024-04-01]
    }

    test "valid changeset with required fields" do
      changeset = TrustTransaction.changeset(%TrustTransaction{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = TrustTransaction.changeset(%TrustTransaction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).trust_account_id
      assert "can't be blank" in errors_on(changeset).transaction_type
      assert "can't be blank" in errors_on(changeset).amount
      assert "can't be blank" in errors_on(changeset).transaction_date
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{transaction_type: "invalid", category: "invalid"})
      changeset = TrustTransaction.changeset(%TrustTransaction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).transaction_type
      assert "is invalid" in errors_on(changeset).category
    end
  end

  # ── 30. Governance.EstatePlan ─────────────────────────────────────────
  # required: [:plan_name, :plan_type, :principal_name]
  # no defaults on required fields (plan_type has no default)

  describe "Governance.EstatePlan" do
    alias Holdco.Governance.EstatePlan

    @valid_attrs %{plan_name: "Last Will", plan_type: "will", principal_name: "John Doe Sr."}

    test "valid changeset with required fields" do
      changeset = EstatePlan.changeset(%EstatePlan{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = EstatePlan.changeset(%EstatePlan{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).plan_name
      assert "can't be blank" in errors_on(changeset).plan_type
      assert "can't be blank" in errors_on(changeset).principal_name
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{plan_type: "invalid", status: "invalid"})
      changeset = EstatePlan.changeset(%EstatePlan{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plan_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 31. Governance.FamilyMember ───────────────────────────────────────
  # required: [:family_charter_id, :full_name, :relationship]
  # no defaults on required fields

  describe "Governance.FamilyMember" do
    alias Holdco.Governance.FamilyMember

    @valid_attrs %{family_charter_id: 1, full_name: "Alice Doe", relationship: "daughter"}

    test "valid changeset with required fields" do
      changeset = FamilyMember.changeset(%FamilyMember{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = FamilyMember.changeset(%FamilyMember{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).family_charter_id
      assert "can't be blank" in errors_on(changeset).full_name
      assert "can't be blank" in errors_on(changeset).relationship
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{role_in_family_office: "invalid", employment_status: "invalid"})
      changeset = FamilyMember.changeset(%FamilyMember{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role_in_family_office
      assert "is invalid" in errors_on(changeset).employment_status
    end
  end

  # ── 32. Governance.SuccessionPlan ─────────────────────────────────────
  # required: [:company_id, :position_title, :current_holder]
  # no defaults on required fields

  describe "Governance.SuccessionPlan" do
    alias Holdco.Governance.SuccessionPlan

    @valid_attrs %{company_id: 1, position_title: "CEO", current_holder: "John Doe"}

    test "valid changeset with required fields" do
      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).company_id
      assert "can't be blank" in errors_on(changeset).position_title
      assert "can't be blank" in errors_on(changeset).current_holder
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{timeline: "invalid", status: "invalid"})
      changeset = SuccessionPlan.changeset(%SuccessionPlan{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).timeline
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 33. Platform.DataLineage ──────────────────────────────────────────
  # required: [:source_type, :target_entity_type, :target_entity_id]
  # no defaults on required fields

  describe "Platform.DataLineage" do
    alias Holdco.Platform.DataLineage

    @valid_attrs %{source_type: "manual_entry", target_entity_type: "transaction", target_entity_id: 42}

    test "valid changeset with required fields" do
      changeset = DataLineage.changeset(%DataLineage{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = DataLineage.changeset(%DataLineage{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).source_type
      assert "can't be blank" in errors_on(changeset).target_entity_type
      assert "can't be blank" in errors_on(changeset).target_entity_id
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{source_type: "invalid", confidence: "invalid"})
      changeset = DataLineage.changeset(%DataLineage{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).source_type
      assert "is invalid" in errors_on(changeset).confidence
    end
  end

  # ── 34. Platform.Plugin ──────────────────────────────────────────────
  # required: [:name, :slug, :plugin_type]
  # no defaults on required fields

  describe "Platform.Plugin" do
    alias Holdco.Platform.Plugin

    @valid_attrs %{name: "Slack Integration", slug: "slack-integration", plugin_type: "integration"}

    test "valid changeset with required fields" do
      changeset = Plugin.changeset(%Plugin{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Plugin.changeset(%Plugin{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).slug
      assert "can't be blank" in errors_on(changeset).plugin_type
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{plugin_type: "invalid", status: "invalid"})
      changeset = Plugin.changeset(%Plugin{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).plugin_type
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 35. Platform.QuickAction ──────────────────────────────────────────
  # required: [:name, :action_type, :target_path]
  # no defaults on required fields

  describe "Platform.QuickAction" do
    alias Holdco.Platform.QuickAction

    @valid_attrs %{name: "New Fund", action_type: "create", target_path: "/funds/new"}

    test "valid changeset with required fields" do
      changeset = QuickAction.changeset(%QuickAction{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = QuickAction.changeset(%QuickAction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).action_type
      assert "can't be blank" in errors_on(changeset).target_path
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{action_type: "invalid", category: "invalid"})
      changeset = QuickAction.changeset(%QuickAction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).action_type
      assert "is invalid" in errors_on(changeset).category
    end
  end

  # ── 36. Collaboration.ContactInteraction ──────────────────────────────
  # required: [:contact_id, :interaction_type, :summary]
  # no defaults on required fields

  describe "Collaboration.ContactInteraction" do
    alias Holdco.Collaboration.ContactInteraction

    @valid_attrs %{contact_id: 1, interaction_type: "call", summary: "Discussed Q1 results"}

    test "valid changeset with required fields" do
      changeset = ContactInteraction.changeset(%ContactInteraction{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ContactInteraction.changeset(%ContactInteraction{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).contact_id
      assert "can't be blank" in errors_on(changeset).interaction_type
      assert "can't be blank" in errors_on(changeset).summary
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{interaction_type: "invalid"})
      changeset = ContactInteraction.changeset(%ContactInteraction{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).interaction_type
    end
  end

  # ── 37. Collaboration.ProjectMilestone ────────────────────────────────
  # required: [:project_id, :name]
  # no defaults on required fields

  describe "Collaboration.ProjectMilestone" do
    alias Holdco.Collaboration.ProjectMilestone

    @valid_attrs %{project_id: 1, name: "Phase 1 Complete"}

    test "valid changeset with required fields" do
      changeset = ProjectMilestone.changeset(%ProjectMilestone{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = ProjectMilestone.changeset(%ProjectMilestone{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).project_id
      assert "can't be blank" in errors_on(changeset).name
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{status: "invalid"})
      changeset = ProjectMilestone.changeset(%ProjectMilestone{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end
  end

  # ── 38. Analytics.Anomaly ─────────────────────────────────────────────
  # required: [:entity_type, :anomaly_type]
  # no defaults on required fields

  describe "Analytics.Anomaly" do
    alias Holdco.Analytics.Anomaly

    @valid_attrs %{entity_type: "transaction", anomaly_type: "outlier"}

    test "valid changeset with required fields" do
      changeset = Anomaly.changeset(%Anomaly{}, @valid_attrs)
      assert changeset.valid?
    end

    test "invalid changeset with missing required fields" do
      changeset = Anomaly.changeset(%Anomaly{}, %{})
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).entity_type
      assert "can't be blank" in errors_on(changeset).anomaly_type
    end

    test "invalid changeset with bad inclusion values" do
      attrs = Map.merge(@valid_attrs, %{entity_type: "invalid", anomaly_type: "invalid", severity: "invalid", status: "invalid"})
      changeset = Anomaly.changeset(%Anomaly{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).entity_type
      assert "is invalid" in errors_on(changeset).anomaly_type
      assert "is invalid" in errors_on(changeset).severity
      assert "is invalid" in errors_on(changeset).status
    end
  end
end
