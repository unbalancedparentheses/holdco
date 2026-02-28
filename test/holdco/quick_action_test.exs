defmodule Holdco.QuickActionTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "quick_actions" do
    test "create_quick_action/1 with valid attrs" do
      {:ok, action} = Platform.create_quick_action(%{
        name: "Test Action",
        description: "A test action",
        action_type: "navigate",
        target_path: "/test",
        category: "portfolio",
        search_keywords: ["test", "qa"]
      })

      assert action.name == "Test Action"
      assert action.action_type == "navigate"
      assert action.target_path == "/test"
      assert action.is_enabled == true
    end

    test "create_quick_action/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_quick_action(%{})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_quick_action/1 validates action_type" do
      assert {:error, changeset} = Platform.create_quick_action(%{
        name: "Bad Type",
        action_type: "invalid",
        target_path: "/test"
      })
      assert %{action_type: _} = errors_on(changeset)
    end

    test "create_quick_action/1 validates category" do
      assert {:error, changeset} = Platform.create_quick_action(%{
        name: "Bad Category",
        action_type: "navigate",
        target_path: "/test",
        category: "invalid_category"
      })
      assert %{category: _} = errors_on(changeset)
    end

    test "create_quick_action/1 enforces unique names" do
      quick_action_fixture(%{name: "Unique Name"})
      assert {:error, changeset} = Platform.create_quick_action(%{
        name: "Unique Name",
        action_type: "navigate",
        target_path: "/other"
      })
      assert %{name: _} = errors_on(changeset)
    end

    test "list_quick_actions/0 returns enabled actions" do
      action = quick_action_fixture()
      actions = Platform.list_quick_actions()
      assert Enum.any?(actions, &(&1.id == action.id))
    end

    test "list_quick_actions/0 excludes disabled actions" do
      {:ok, action} = Platform.create_quick_action(%{
        name: "Disabled #{System.unique_integer([:positive])}",
        action_type: "navigate",
        target_path: "/disabled",
        is_enabled: false
      })

      actions = Platform.list_quick_actions()
      refute Enum.any?(actions, &(&1.id == action.id))
    end

    test "search_quick_actions/1 finds by name" do
      quick_action_fixture(%{name: "FindMe Special"})
      results = Platform.search_quick_actions("FindMe")
      assert Enum.any?(results, &(&1.name == "FindMe Special"))
    end

    test "search_quick_actions/1 finds by keyword" do
      quick_action_fixture(%{name: "KeywordTest #{System.unique_integer([:positive])}", search_keywords: ["unique_kw_xyz"]})
      results = Platform.search_quick_actions("unique_kw_xyz")
      assert length(results) >= 1
    end

    test "search_quick_actions/1 is case insensitive" do
      quick_action_fixture(%{name: "CaseTest Special"})
      results = Platform.search_quick_actions("casetest")
      assert Enum.any?(results, &String.contains?(&1.name, "CaseTest"))
    end

    test "get_quick_action!/1 returns the action" do
      action = quick_action_fixture()
      found = Platform.get_quick_action!(action.id)
      assert found.id == action.id
    end

    test "get_quick_action!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_quick_action!(0)
      end
    end

    test "update_quick_action/2 updates successfully" do
      action = quick_action_fixture()
      {:ok, updated} = Platform.update_quick_action(action, %{description: "Updated desc"})
      assert updated.description == "Updated desc"
    end

    test "delete_quick_action/1 deletes the action" do
      action = quick_action_fixture()
      {:ok, _} = Platform.delete_quick_action(action)
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_quick_action!(action.id)
      end
    end

    test "seed_default_actions/0 creates default actions" do
      results = Platform.seed_default_actions()
      assert length(results) >= 10
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end

    test "seed_default_actions/0 is idempotent" do
      Platform.seed_default_actions()
      results = Platform.seed_default_actions()
      assert Enum.all?(results, fn {status, _} -> status == :ok end)
    end

    test "quick actions are ordered by sort_order then name" do
      a1 = quick_action_fixture(%{name: "Zzz Action", sort_order: 1})
      a2 = quick_action_fixture(%{name: "Aaa Action", sort_order: 2})

      actions = Platform.list_quick_actions()
      ids = Enum.map(actions, & &1.id)
      idx1 = Enum.find_index(ids, &(&1 == a1.id))
      idx2 = Enum.find_index(ids, &(&1 == a2.id))
      assert idx1 < idx2
    end
  end
end
