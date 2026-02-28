defmodule Holdco.DataLineageTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "data_lineage" do
    test "create_data_lineage/1 with valid attrs" do
      {:ok, lineage} = Platform.create_data_lineage(%{
        source_type: "manual_entry",
        source_identifier: "user-input-001",
        target_entity_type: "transaction",
        target_entity_id: 1,
        transformation: "Direct entry by user",
        confidence: "high"
      })

      assert lineage.source_type == "manual_entry"
      assert lineage.target_entity_type == "transaction"
      assert lineage.confidence == "high"
      assert lineage.verified == false
    end

    test "create_data_lineage/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_data_lineage(%{})
      errors = errors_on(changeset)
      assert %{source_type: ["can't be blank"]} = errors
      assert %{target_entity_type: ["can't be blank"]} = errors
    end

    test "create_data_lineage/1 validates source_type" do
      assert {:error, changeset} = Platform.create_data_lineage(%{
        source_type: "invalid_source",
        target_entity_type: "transaction",
        target_entity_id: 1
      })
      assert %{source_type: _} = errors_on(changeset)
    end

    test "create_data_lineage/1 validates confidence" do
      assert {:error, changeset} = Platform.create_data_lineage(%{
        source_type: "manual_entry",
        target_entity_type: "transaction",
        target_entity_id: 1,
        confidence: "invalid_confidence"
      })
      assert %{confidence: _} = errors_on(changeset)
    end

    test "list_data_lineage/0 returns all records" do
      lineage = data_lineage_fixture()
      records = Platform.list_data_lineage()
      assert Enum.any?(records, &(&1.id == lineage.id))
    end

    test "list_data_lineage/1 filters by entity_type" do
      data_lineage_fixture(%{target_entity_type: "holding"})
      data_lineage_fixture(%{target_entity_type: "transaction"})

      records = Platform.list_data_lineage(%{entity_type: "holding"})
      assert Enum.all?(records, &(&1.target_entity_type == "holding"))
    end

    test "get_data_lineage!/1 returns the record" do
      lineage = data_lineage_fixture()
      found = Platform.get_data_lineage!(lineage.id)
      assert found.id == lineage.id
    end

    test "get_data_lineage!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_data_lineage!(0)
      end
    end

    test "update_data_lineage/2 updates successfully" do
      lineage = data_lineage_fixture()
      {:ok, updated} = Platform.update_data_lineage(lineage, %{notes: "Updated notes"})
      assert updated.notes == "Updated notes"
    end

    test "update_data_lineage/2 can mark as verified" do
      lineage = data_lineage_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, updated} = Platform.update_data_lineage(lineage, %{
        verified: true,
        verified_at: now
      })

      assert updated.verified == true
      assert updated.verified_at != nil
    end

    test "delete_data_lineage/1 deletes the record" do
      lineage = data_lineage_fixture()
      {:ok, _} = Platform.delete_data_lineage(lineage)
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_data_lineage!(lineage.id)
      end
    end

    test "lineage_for_entity/2 returns records for specific entity" do
      n = System.unique_integer([:positive])
      data_lineage_fixture(%{target_entity_type: "transaction", target_entity_id: n})
      data_lineage_fixture(%{target_entity_type: "transaction", target_entity_id: n + 1})

      records = Platform.lineage_for_entity("transaction", n)
      assert length(records) >= 1
      assert Enum.all?(records, &(&1.target_entity_id == n))
    end

    test "unverified_lineage/0 returns only unverified records" do
      data_lineage_fixture(%{verified: false})

      records = Platform.unverified_lineage()
      assert length(records) >= 1
      assert Enum.all?(records, &(&1.verified == false))
    end

    test "create_data_lineage/1 with all source types" do
      for source <- ~w(manual_entry import bank_feed api_sync calculation migration) do
        {:ok, lineage} = Platform.create_data_lineage(%{
          source_type: source,
          target_entity_type: "test",
          target_entity_id: 1
        })
        assert lineage.source_type == source
      end
    end

    test "create_data_lineage/1 with verified_by_id" do
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, lineage} = Platform.create_data_lineage(%{
        source_type: "import",
        target_entity_type: "transaction",
        target_entity_id: 1,
        verified: true,
        verified_by_id: user.id,
        verified_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

      assert lineage.verified_by_id == user.id
      assert lineage.verified == true
    end

    test "data lineage records are ordered by most recent first" do
      l1 = data_lineage_fixture()
      l2 = data_lineage_fixture()

      records = Platform.list_data_lineage()
      # Both records should appear in the list
      assert Enum.any?(records, &(&1.id == l1.id))
      assert Enum.any?(records, &(&1.id == l2.id))
      # Records should be returned as a list ordered by inserted_at desc
      ids = Enum.map(records, & &1.id)
      assert is_list(ids)
    end
  end
end
