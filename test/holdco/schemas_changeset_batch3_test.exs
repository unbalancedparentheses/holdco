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
end
