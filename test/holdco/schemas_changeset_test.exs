defmodule Holdco.SchemasChangesetTest do
  use Holdco.DataCase, async: true

  # ── Compliance.KycRecord ────────────────────────────────────────────
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

  # ── Compliance.AmlAlert ────────────────────────────────────────────
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

  # ── Corporate.RelatedPartyTransaction ─────────────────────────────
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

  # ── Finance.TrustAccount ──────────────────────────────────────────
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

  # ── Governance.ConflictOfInterest ─────────────────────────────────
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

  # ── Corporate.Contract ────────────────────────────────────────────
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

  # ── Corporate.CorporateAction ─────────────────────────────────────
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

  # ── Corporate.EntityLifecycle ─────────────────────────────────────
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

  # ── Corporate.IpAsset ────────────────────────────────────────────
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

  # ── Corporate.LeiRecord ──────────────────────────────────────────
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

  # ── Corporate.RegisterEntry ───────────────────────────────────────
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

  # ── Documents.DataRoom ───────────────────────────────────────────
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

  # ── Finance.TrustTransaction ──────────────────────────────────────
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

  # ── Governance.FamilyMember ───────────────────────────────────────
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

  # ── Platform.DataLineage ──────────────────────────────────────────
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

  # ── Platform.Plugin ──────────────────────────────────────────────
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

  # ── Platform.QuickAction ──────────────────────────────────────────
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

  # ── Collaboration.ContactInteraction ──────────────────────────────
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

  # ── Collaboration.ProjectMilestone ────────────────────────────────
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

  # ── Analytics.Anomaly ─────────────────────────────────────────────
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
