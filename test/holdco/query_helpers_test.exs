defmodule Holdco.QueryHelpersTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.QueryHelpers
  alias Holdco.Corporate.Company

  describe "apply_filters/2" do
    test "returns unfiltered query for empty map" do
      company_fixture(%{name: "Test"})
      results = Company |> QueryHelpers.apply_filters(%{}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "filters by field" do
      company_fixture(%{country: "JP"})
      results = Company |> QueryHelpers.apply_filters(%{country: "JP"}) |> Holdco.Repo.all()
      assert Enum.all?(results, &(&1.country == "JP"))
    end

    test "ignores nil values" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(%{country: nil}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "ignores empty string values" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(%{country: ""}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "handles non-map filters" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(nil) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "handles list as filter argument" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters([]) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "handles atom as filter argument" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(:invalid) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "ignores unknown fields" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(%{nonexistent_field: "x"}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "sort_by applies ordering" do
      company_fixture(%{name: "AAA Corp"})
      company_fixture(%{name: "ZZZ Corp"})
      results = Company |> QueryHelpers.apply_filters(%{sort_by: :name}) |> Holdco.Repo.all()
      names = Enum.map(results, & &1.name)
      assert names == Enum.sort(names)
    end

    test "sort_dir alone does not crash" do
      company_fixture(%{name: "Test"})
      results = Company |> QueryHelpers.apply_filters(%{sort_dir: :asc}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "multiple filters applied together" do
      company_fixture(%{name: "FilterTest US", country: "US"})
      company_fixture(%{name: "FilterTest JP", country: "JP"})
      company_fixture(%{name: "Other US", country: "US"})

      results = Company |> QueryHelpers.apply_filters(%{country: "US"}) |> Holdco.Repo.all()
      assert Enum.all?(results, &(&1.country == "US"))
      assert length(results) >= 2
    end

    test "sort_by with filter" do
      company_fixture(%{name: "CCC Corp", country: "US"})
      company_fixture(%{name: "AAA Corp", country: "US"})
      company_fixture(%{name: "BBB Corp", country: "JP"})

      results = Company |> QueryHelpers.apply_filters(%{country: "US", sort_by: :name}) |> Holdco.Repo.all()
      assert Enum.all?(results, &(&1.country == "US"))
      names = Enum.map(results, & &1.name)
      assert names == Enum.sort(names)
    end

    test "filters by name field" do
      company_fixture(%{name: "Unique Name XYZ123"})
      company_fixture(%{name: "Other Company"})

      results = Company |> QueryHelpers.apply_filters(%{name: "Unique Name XYZ123"}) |> Holdco.Repo.all()
      assert length(results) == 1
      assert hd(results).name == "Unique Name XYZ123"
    end

    test "no results for non-matching filter" do
      company_fixture(%{country: "US"})
      results = Company |> QueryHelpers.apply_filters(%{country: "ZZ"}) |> Holdco.Repo.all()
      assert results == []
    end

    test "multiple nil/empty filters are all ignored" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(%{country: nil, name: ""}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "sort_by with non-atom value is ignored" do
      company_fixture()
      # sort_by with a string value should not apply (guard requires atom)
      results = Company |> QueryHelpers.apply_filters(%{sort_by: "name"}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "sort_dir with non-nil value is a passthrough" do
      company_fixture(%{name: "SortDirTest"})
      # sort_dir with :desc is just a no-op pass-through
      results = Company |> QueryHelpers.apply_filters(%{sort_dir: :desc}) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "apply_filters with integer as non-map argument" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(42) |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "apply_filters with string as non-map argument" do
      company_fixture()
      results = Company |> QueryHelpers.apply_filters("invalid") |> Holdco.Repo.all()
      assert length(results) > 0
    end

    test "has_field? returns false for non-schema queries" do
      # Passing a plain query should handle the rescue path
      company_fixture()
      results = Company |> QueryHelpers.apply_filters(%{fake_field_xyz: "value"}) |> Holdco.Repo.all()
      assert is_list(results)
    end
  end
end
