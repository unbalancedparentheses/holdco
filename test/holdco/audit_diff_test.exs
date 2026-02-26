defmodule Holdco.AuditDiffTest do
  use Holdco.DataCase

  alias Holdco.AuditDiff

  describe "compute_diff/1" do
    test "extracts old and new values from changeset" do
      company = %Holdco.Corporate.Company{name: "Old Name", country: "US"}

      changeset =
        Ecto.Changeset.change(company, %{name: "New Name"})

      result = AuditDiff.compute_diff(changeset)

      assert is_binary(result.old_values)
      assert is_binary(result.new_values)

      old = Jason.decode!(result.old_values)
      new = Jason.decode!(result.new_values)

      assert old["name"] == "Old Name"
      assert new["name"] == "New Name"
    end

    test "handles multiple changed fields" do
      company = %Holdco.Corporate.Company{name: "OldCo", country: "US"}

      changeset =
        Ecto.Changeset.change(company, %{name: "NewCo", country: "UK"})

      result = AuditDiff.compute_diff(changeset)

      old = Jason.decode!(result.old_values)
      new = Jason.decode!(result.new_values)

      assert old["name"] == "OldCo"
      assert old["country"] == "US"
      assert new["name"] == "NewCo"
      assert new["country"] == "UK"
    end

    test "returns empty maps when no changes" do
      company = %Holdco.Corporate.Company{name: "Same"}

      changeset = Ecto.Changeset.change(company, %{})

      result = AuditDiff.compute_diff(changeset)

      old = Jason.decode!(result.old_values)
      new = Jason.decode!(result.new_values)

      assert old == %{}
      assert new == %{}
    end
  end

  describe "format_diff/2" do
    test "returns diffs for changed fields" do
      old = Jason.encode!(%{"name" => "Alpha", "country" => "US"})
      new = Jason.encode!(%{"name" => "Beta", "country" => "US"})

      diffs = AuditDiff.format_diff(old, new)

      assert length(diffs) == 1
      diff = hd(diffs)
      assert diff.field == "name"
      assert diff.old_value == "Alpha"
      assert diff.new_value == "Beta"
    end

    test "returns empty list when values are the same" do
      old = Jason.encode!(%{"name" => "Same"})
      new = Jason.encode!(%{"name" => "Same"})

      assert AuditDiff.format_diff(old, new) == []
    end

    test "handles nil inputs" do
      assert AuditDiff.format_diff(nil, nil) == []
    end

    test "handles added fields (old is nil for a key)" do
      old = Jason.encode!(%{})
      new = Jason.encode!(%{"name" => "Added"})

      diffs = AuditDiff.format_diff(old, new)

      assert length(diffs) == 1
      diff = hd(diffs)
      assert diff.field == "name"
      assert diff.old_value == nil
      assert diff.new_value == "Added"
    end

    test "handles removed fields (new is nil for a key)" do
      old = Jason.encode!(%{"name" => "Removed"})
      new = Jason.encode!(%{})

      diffs = AuditDiff.format_diff(old, new)

      assert length(diffs) == 1
      diff = hd(diffs)
      assert diff.field == "name"
      assert diff.old_value == "Removed"
      assert diff.new_value == nil
    end

    test "handles multiple changed fields" do
      old = Jason.encode!(%{"a" => 1, "b" => 2, "c" => 3})
      new = Jason.encode!(%{"a" => 1, "b" => 99, "c" => 100})

      diffs = AuditDiff.format_diff(old, new)

      assert length(diffs) == 2
      fields = Enum.map(diffs, & &1.field) |> Enum.sort()
      assert fields == ["b", "c"]
    end

    test "handles empty string JSON" do
      assert AuditDiff.format_diff("", "") == []
    end

    test "handles invalid JSON gracefully" do
      assert AuditDiff.format_diff("not json", "also not json") == []
    end
  end
end
