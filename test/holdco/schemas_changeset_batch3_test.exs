defmodule Holdco.SchemasChangesetBatch3Test do
  use Holdco.DataCase, async: true

  # ── 1. Compliance.KycRecord ──────────────────────────────────────────
  # Gaps: risk_levels/0, verification_statuses/0, id_types/0 helper functions

  describe "Compliance.KycRecord helper functions" do
    alias Holdco.Compliance.KycRecord

    test "risk_levels/0 returns expected list" do
      assert KycRecord.risk_levels() == ~w(low medium high pep)
    end

    test "verification_statuses/0 returns expected list" do
      assert KycRecord.verification_statuses() ==
               ~w(not_started documents_requested under_review verified rejected expired)
    end

    test "id_types/0 returns expected list" do
      assert KycRecord.id_types() == ~w(passport national_id drivers_license corporate_registration)
    end
  end

  # ── 2. Compliance.BcpPlan ────────────────────────────────────────────
  # Gaps: statuses/0, test_results/0 helper functions

  describe "Compliance.BcpPlan helper functions" do
    alias Holdco.Compliance.BcpPlan

    test "statuses/0 returns expected list" do
      assert BcpPlan.statuses() == ~w(draft approved active under_review retired)
    end

    test "test_results/0 returns expected list" do
      assert BcpPlan.test_results() == ~w(passed partial failed not_tested)
    end
  end

  # ── 3. Compliance.Litigation ─────────────────────────────────────────
  # Gaps: party_roles/0, statuses/0 helper functions

  describe "Compliance.Litigation helper functions" do
    alias Holdco.Compliance.Litigation

    test "party_roles/0 returns expected list" do
      assert Litigation.party_roles() == ~w(plaintiff defendant respondent petitioner)
    end

    test "statuses/0 returns expected list" do
      assert Litigation.statuses() ==
               ~w(pre_filing active discovery trial appeal settled dismissed closed)
    end
  end

  # ── 4. Finance.TrustAccount ─────────────────────────────────────────
  # Gaps: statuses/0, distribution_schedules/0 helper functions, full optional fields

  describe "Finance.TrustAccount helper functions and optional fields" do
    alias Holdco.Finance.TrustAccount

    @valid_attrs %{company_id: 1, trust_name: "Dynasty Trust", trust_type: "irrevocable", trustee_name: "First National Bank"}

    test "statuses/0 returns expected list" do
      assert TrustAccount.statuses() == ~w(active terminated pending suspended)
    end

    test "distribution_schedules/0 returns expected list" do
      assert TrustAccount.distribution_schedules() == ~w(monthly quarterly annually discretionary)
    end

    test "valid changeset with all optional fields populated" do
      attrs =
        Map.merge(@valid_attrs, %{
          grantor_name: "John Smith",
          beneficiaries: [%{"name" => "Alice", "share" => "50%"}],
          jurisdiction: "Delaware",
          date_established: ~D[2020-01-15],
          corpus_value: Decimal.new("5000000"),
          currency: "EUR",
          distribution_schedule: "annually",
          last_distribution_date: ~D[2024-06-30],
          next_distribution_date: ~D[2025-06-30],
          tax_id: "12-3456789",
          status: "active",
          notes: "Multi-generational trust"
        })

      changeset = TrustAccount.changeset(%TrustAccount{}, attrs)
      assert changeset.valid?
    end
  end

  # ── 5. Compliance.EmissionsRecord ────────────────────────────────────
  # Gaps: units/0, verification_statuses/0 helper functions

  describe "Compliance.EmissionsRecord helper functions" do
    alias Holdco.Compliance.EmissionsRecord

    test "units/0 returns expected list" do
      assert EmissionsRecord.units() == ~w(tonnes_co2e kg_co2e mwh liters km)
    end

    test "verification_statuses/0 returns expected list" do
      assert EmissionsRecord.verification_statuses() == ~w(unverified self_assessed third_party_verified)
    end
  end

  # ── 6. Governance.EthicsReport ───────────────────────────────────────
  # Gaps: severities/0, statuses/0 helper functions, full optional fields

  describe "Governance.EthicsReport helper functions and optional fields" do
    alias Holdco.Governance.EthicsReport

    @valid_attrs %{
      company_id: 1,
      report_type: "fraud",
      reporter_type: "named_internal",
      severity: "high",
      description: "Unauthorized expense reports",
      reported_date: ~D[2024-08-01]
    }

    test "severities/0 returns expected list" do
      assert EthicsReport.severities() == ~w(low medium high critical)
    end

    test "statuses/0 returns expected list" do
      assert EthicsReport.statuses() == ~w(received under_investigation escalated resolved dismissed)
    end

    test "valid changeset with all optional fields populated" do
      attrs =
        Map.merge(@valid_attrs, %{
          reporter_name: "Jane Doe",
          involved_parties: "CFO, Controller",
          status: "under_investigation",
          assigned_investigator: "External Counsel",
          investigation_notes: "Reviewing expense records",
          resolution: nil,
          resolved_date: nil,
          notes: "Priority investigation"
        })

      changeset = EthicsReport.changeset(%EthicsReport{}, attrs)
      assert changeset.valid?
    end
  end

  # ── 7. Compliance.InsuranceClaim ─────────────────────────────────────
  # Gaps: statuses/0 helper function

  describe "Compliance.InsuranceClaim helper functions" do
    alias Holdco.Compliance.InsuranceClaim

    test "statuses/0 returns expected list" do
      assert InsuranceClaim.statuses() == ~w(filed under_review approved denied settled closed)
    end
  end

  # ── 8. Corporate.EntityLifecycle ─────────────────────────────────────
  # Gaps: statuses/0 helper function

  describe "Corporate.EntityLifecycle helper functions" do
    alias Holdco.Corporate.EntityLifecycle

    test "statuses/0 returns expected list" do
      assert EntityLifecycle.statuses() == ~w(pending completed rejected)
    end
  end

  # ── 9. Corporate.IpAsset ────────────────────────────────────────────
  # Gaps: statuses/0 helper function

  describe "Corporate.IpAsset helper functions" do
    alias Holdco.Corporate.IpAsset

    test "statuses/0 returns expected list" do
      assert IpAsset.statuses() == ~w(pending active expired abandoned transferred)
    end
  end

  # ── 10. Documents.DataRoom ──────────────────────────────────────────
  # Gaps: statuses/0 helper function

  describe "Documents.DataRoom helper functions" do
    alias Holdco.Documents.DataRoom

    test "statuses/0 returns expected list" do
      assert DataRoom.statuses() == ~w(active archived expired)
    end
  end

  # ── 11. Finance.BankGuarantee ───────────────────────────────────────
  # Gaps: statuses/0 helper function, full optional fields

  describe "Finance.BankGuarantee helper functions and optional fields" do
    alias Holdco.Finance.BankGuarantee

    @valid_attrs %{
      company_id: 1,
      guarantee_type: "financial",
      issuing_bank: "Deutsche Bank",
      beneficiary: "Project Co Ltd",
      amount: Decimal.new("250000")
    }

    test "statuses/0 returns expected list" do
      assert BankGuarantee.statuses() == ~w(active expired called released renewed)
    end

    test "valid changeset with all optional fields populated" do
      attrs =
        Map.merge(@valid_attrs, %{
          reference_number: "BG-2024-001",
          currency: "EUR",
          issue_date: ~D[2024-01-15],
          expiry_date: ~D[2025-01-15],
          status: "active",
          annual_fee_pct: Decimal.new("1.5"),
          collateral_description: "Fixed deposit of EUR 250,000",
          purpose: "Project performance guarantee",
          notes: "Renewable annually"
        })

      changeset = BankGuarantee.changeset(%BankGuarantee{}, attrs)
      assert changeset.valid?
    end
  end

  # ── 12. Governance.EstatePlan ───────────────────────────────────────
  # Gaps: statuses/0 helper function

  describe "Governance.EstatePlan helper functions" do
    alias Holdco.Governance.EstatePlan

    test "statuses/0 returns expected list" do
      assert EstatePlan.statuses() == ~w(draft executed filed superseded revoked)
    end
  end
end
