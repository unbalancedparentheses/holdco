defmodule Holdco.SchemaHelpersTest do
  @moduledoc """
  Tests for schema-level helper functions (constants accessors)
  that return lists of allowed values for validated fields.
  """
  use ExUnit.Case, async: true

  # ── AmlAlert ─────────────────────────────────────────

  describe "Holdco.Compliance.AmlAlert helpers" do
    test "alert_types/0 returns known types" do
      types = Holdco.Compliance.AmlAlert.alert_types()
      assert is_list(types)
      assert "large_transaction" in types
      assert "structuring" in types
    end

    test "severities/0 returns known severities" do
      sevs = Holdco.Compliance.AmlAlert.severities()
      assert is_list(sevs)
      assert "low" in sevs
      assert "critical" in sevs
    end

    test "statuses/0 returns known statuses" do
      statuses = Holdco.Compliance.AmlAlert.statuses()
      assert is_list(statuses)
      assert "open" in statuses
      assert "filed_sar" in statuses
    end
  end

  # ── ConflictOfInterest ───────────────────────────────

  describe "Holdco.Governance.ConflictOfInterest helpers" do
    test "declarant_roles/0 returns known roles" do
      roles = Holdco.Governance.ConflictOfInterest.declarant_roles()
      assert is_list(roles)
      assert "director" in roles
      assert "officer" in roles
    end

    test "conflict_types/0 returns known types" do
      types = Holdco.Governance.ConflictOfInterest.conflict_types()
      assert is_list(types)
      assert "financial" in types
      assert "personal" in types
    end

    test "statuses/0 returns known statuses" do
      statuses = Holdco.Governance.ConflictOfInterest.statuses()
      assert is_list(statuses)
      assert "declared" in statuses
      assert "resolved" in statuses
    end
  end

  # ── DeferredTax changeset ────────────────────────────

  describe "Holdco.Tax.DeferredTax changeset" do
    alias Holdco.Tax.DeferredTax

    test "valid changeset with all required fields" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Depreciation timing diff",
        deferred_type: "asset"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      assert changeset.valid?
    end

    test "invalid changeset without required fields" do
      changeset = DeferredTax.changeset(%DeferredTax{}, %{})
      refute changeset.valid?
    end

    test "validates deferred_type inclusion" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Test",
        deferred_type: "invalid"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :deferred_type)
    end

    test "validates source with valid value" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Test",
        deferred_type: "asset",
        source: "depreciation"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      assert changeset.valid?
    end

    test "validates source with invalid value" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Test",
        deferred_type: "liability",
        source: "not_a_valid_source"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :source)
    end

    test "validates tax_year range" do
      attrs = %{
        company_id: 1,
        tax_year: 1800,
        description: "Test",
        deferred_type: "asset"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :tax_year)
    end

    test "validates tax_rate range" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Test",
        deferred_type: "asset",
        tax_rate: 150
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      refute changeset.valid?
      assert Keyword.has_key?(changeset.errors, :tax_rate)
    end

    test "accepts all valid source values" do
      for source <- ~w(depreciation unrealized_gains accrued_expenses nol_carryforward lease_liability) do
        attrs = %{
          company_id: 1,
          tax_year: 2025,
          description: "Test #{source}",
          deferred_type: "asset",
          source: source
        }

        changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
        assert changeset.valid?, "Expected source '#{source}' to be valid"
      end
    end

    test "accepts nil source" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "No source",
        deferred_type: "asset"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      assert changeset.valid?
    end

    test "accepts optional numeric fields" do
      attrs = %{
        company_id: 1,
        tax_year: 2025,
        description: "Full fields",
        deferred_type: "liability",
        book_basis: "100000",
        tax_basis: "80000",
        temporary_difference: "20000",
        tax_rate: "21.0",
        deferred_amount: "4200",
        is_current: true,
        notes: "Test notes"
      }

      changeset = DeferredTax.changeset(%DeferredTax{}, attrs)
      assert changeset.valid?
    end
  end
end
