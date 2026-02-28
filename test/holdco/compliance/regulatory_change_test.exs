defmodule Holdco.Compliance.RegulatoryChangeTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Compliance

  describe "regulatory_changes CRUD" do
    test "list_regulatory_changes/0 returns all changes" do
      change = regulatory_change_fixture()
      results = Compliance.list_regulatory_changes()
      assert Enum.any?(results, &(&1.id == change.id))
    end

    test "get_regulatory_change!/1 returns the change" do
      change = regulatory_change_fixture()
      fetched = Compliance.get_regulatory_change!(change.id)
      assert fetched.id == change.id
    end

    test "get_regulatory_change!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_regulatory_change!(0)
      end
    end

    test "create_regulatory_change/1 with valid data" do
      assert {:ok, change} =
               Compliance.create_regulatory_change(%{
                 title: "New Tax Regulation",
                 jurisdiction: "EU",
                 regulatory_body: "European Commission",
                 change_type: "new_regulation",
                 effective_date: "2026-06-01",
                 description: "New tax transparency requirements",
                 impact_assessment: "high",
                 status: "monitoring"
               })

      assert change.title == "New Tax Regulation"
      assert change.jurisdiction == "EU"
      assert change.impact_assessment == "high"
    end

    test "create_regulatory_change/1 with all change types" do
      for type <- ~w(new_regulation amendment repeal guidance enforcement) do
        assert {:ok, change} =
                 Compliance.create_regulatory_change(%{
                   title: "Change #{type}",
                   jurisdiction: "US",
                   change_type: type
                 })

        assert change.change_type == type
      end
    end

    test "create_regulatory_change/1 with all impact levels" do
      for level <- ~w(low medium high critical) do
        assert {:ok, change} =
                 Compliance.create_regulatory_change(%{
                   title: "Impact #{level}",
                   jurisdiction: "US",
                   change_type: "new_regulation",
                   impact_assessment: level
                 })

        assert change.impact_assessment == level
      end
    end

    test "create_regulatory_change/1 fails without required fields" do
      assert {:error, changeset} = Compliance.create_regulatory_change(%{})
      errors = errors_on(changeset)
      assert errors[:title]
      assert errors[:jurisdiction]
      assert errors[:change_type]
    end

    test "create_regulatory_change/1 fails with invalid change_type" do
      assert {:error, changeset} =
               Compliance.create_regulatory_change(%{
                 title: "Test",
                 jurisdiction: "US",
                 change_type: "invalid"
               })

      assert errors_on(changeset)[:change_type]
    end

    test "create_regulatory_change/1 fails with invalid impact_assessment" do
      assert {:error, changeset} =
               Compliance.create_regulatory_change(%{
                 title: "Test",
                 jurisdiction: "US",
                 change_type: "new_regulation",
                 impact_assessment: "invalid"
               })

      assert errors_on(changeset)[:impact_assessment]
    end

    test "create_regulatory_change/1 fails with invalid status" do
      assert {:error, changeset} =
               Compliance.create_regulatory_change(%{
                 title: "Test",
                 jurisdiction: "US",
                 change_type: "new_regulation",
                 status: "invalid"
               })

      assert errors_on(changeset)[:status]
    end

    test "update_regulatory_change/2 with valid data" do
      change = regulatory_change_fixture()

      assert {:ok, updated} =
               Compliance.update_regulatory_change(change, %{
                 title: "Updated Title",
                 impact_assessment: "critical",
                 status: "implementation"
               })

      assert updated.title == "Updated Title"
      assert updated.impact_assessment == "critical"
      assert updated.status == "implementation"
    end

    test "delete_regulatory_change/1 removes the change" do
      change = regulatory_change_fixture()
      assert {:ok, _} = Compliance.delete_regulatory_change(change)

      assert_raise Ecto.NoResultsError, fn ->
        Compliance.get_regulatory_change!(change.id)
      end
    end
  end

  describe "pending_regulatory_changes/0" do
    test "returns only monitoring and assessment changes" do
      monitoring = regulatory_change_fixture(%{status: "monitoring"})
      assessment = regulatory_change_fixture(%{status: "assessment"})
      _completed = regulatory_change_fixture(%{status: "completed"})

      results = Compliance.pending_regulatory_changes()
      ids = Enum.map(results, & &1.id)
      assert monitoring.id in ids
      assert assessment.id in ids
    end
  end

  describe "high_impact_changes/0" do
    test "returns only high and critical impact changes" do
      high = regulatory_change_fixture(%{impact_assessment: "high"})
      critical = regulatory_change_fixture(%{impact_assessment: "critical"})
      _low = regulatory_change_fixture(%{impact_assessment: "low"})

      results = Compliance.high_impact_changes()
      ids = Enum.map(results, & &1.id)
      assert high.id in ids
      assert critical.id in ids
    end
  end

  describe "regulatory_change schema" do
    test "change_types returns valid types" do
      types = Holdco.Compliance.RegulatoryChange.change_types()
      assert "new_regulation" in types
      assert "amendment" in types
    end

    test "impact_levels returns valid levels" do
      levels = Holdco.Compliance.RegulatoryChange.impact_levels()
      assert "low" in levels
      assert "critical" in levels
    end

    test "statuses returns valid statuses" do
      statuses = Holdco.Compliance.RegulatoryChange.statuses()
      assert "monitoring" in statuses
      assert "completed" in statuses
    end

    test "create with affected_entities array" do
      assert {:ok, change} =
               Compliance.create_regulatory_change(%{
                 title: "Test Entities",
                 jurisdiction: "US",
                 change_type: "new_regulation",
                 affected_entities: ["Fund A", "Fund B", "Corp C"]
               })

      assert change.affected_entities == ["Fund A", "Fund B", "Corp C"]
    end

    test "create with action_items array of maps" do
      assert {:ok, change} =
               Compliance.create_regulatory_change(%{
                 title: "Test Actions",
                 jurisdiction: "US",
                 change_type: "new_regulation",
                 action_items: [
                   %{"task" => "Review impact", "due_date" => "2026-03-01"},
                   %{"task" => "Update policies", "due_date" => "2026-04-01"}
                 ]
               })

      assert length(change.action_items) == 2
    end
  end
end
