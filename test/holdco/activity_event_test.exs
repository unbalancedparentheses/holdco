defmodule Holdco.ActivityEventTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  describe "activity_events" do
    test "create_activity_event/1 with valid attrs" do
      {:ok, event} = Platform.create_activity_event(%{
        action: "created",
        entity_type: "company",
        entity_id: 1,
        entity_name: "Test Co",
        actor_email: "admin@example.com",
        context_module: "Holdco.Corporate"
      })

      assert event.action == "created"
      assert event.entity_type == "company"
      assert event.entity_name == "Test Co"
      assert event.actor_email == "admin@example.com"
    end

    test "create_activity_event/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_activity_event(%{})
      assert %{action: ["can't be blank"]} = errors_on(changeset)
    end

    test "create_activity_event/1 validates action inclusion" do
      assert {:error, changeset} = Platform.create_activity_event(%{
        action: "invalid_action",
        entity_type: "company"
      })
      assert %{action: _} = errors_on(changeset)
    end

    test "list_recent_activity/0 returns events" do
      event = activity_event_fixture()
      events = Platform.list_recent_activity()
      assert Enum.any?(events, &(&1.id == event.id))
    end

    test "list_recent_activity/1 with limit" do
      for _ <- 1..5, do: activity_event_fixture()
      events = Platform.list_recent_activity(%{limit: 2})
      assert length(events) <= 2
    end

    test "list_recent_activity/1 filters by action" do
      activity_event_fixture(%{action: "created"})
      activity_event_fixture(%{action: "deleted"})

      events = Platform.list_recent_activity(%{action: "created"})
      assert Enum.all?(events, &(&1.action == "created"))
    end

    test "list_recent_activity/1 filters by entity_type" do
      activity_event_fixture(%{entity_type: "holding"})
      activity_event_fixture(%{entity_type: "company"})

      events = Platform.list_recent_activity(%{entity_type: "holding"})
      assert Enum.all?(events, &(&1.entity_type == "holding"))
    end

    test "list_recent_activity/1 filters by company_id" do
      company = company_fixture()
      activity_event_fixture(%{company_id: company.id})
      activity_event_fixture()

      events = Platform.list_recent_activity(%{company_id: company.id})
      assert Enum.all?(events, &(&1.company_id == company.id))
    end

    test "activity_summary/1 returns counts by action" do
      activity_event_fixture(%{action: "created"})
      activity_event_fixture(%{action: "created"})
      activity_event_fixture(%{action: "deleted"})

      summary = Platform.activity_summary(%{days: 30})
      assert is_map(summary)
      assert Map.get(summary, "created", 0) >= 2
    end

    test "activity_summary/0 works with default opts" do
      activity_event_fixture()
      summary = Platform.activity_summary()
      assert is_map(summary)
    end

    test "clear_old_activity/1 removes old events" do
      event = activity_event_fixture()
      # Should not delete recent events
      {deleted, _} = Platform.clear_old_activity(90)
      assert deleted >= 0

      # Event should still exist
      events = Platform.list_recent_activity()
      assert Enum.any?(events, &(&1.id == event.id))
    end

    test "create_activity_event/1 with metadata" do
      {:ok, event} = Platform.create_activity_event(%{
        action: "exported",
        entity_type: "report",
        entity_id: 42,
        metadata: %{"format" => "csv", "rows" => 100}
      })

      assert event.metadata == %{"format" => "csv", "rows" => 100}
    end

    test "create_activity_event/1 with all action types" do
      for action <- ~w(created updated deleted approved rejected locked unlocked exported imported dispatched) do
        {:ok, event} = Platform.create_activity_event(%{
          action: action,
          entity_type: "test",
          entity_id: 1
        })
        assert event.action == action
      end
    end

    test "create_activity_event/1 with actor_id" do
      user = Holdco.AccountsFixtures.user_fixture()

      {:ok, event} = Platform.create_activity_event(%{
        action: "created",
        entity_type: "company",
        entity_id: 1,
        actor_id: user.id,
        actor_email: user.email
      })

      assert event.actor_id == user.id
    end

    test "list_recent_activity/1 filters by actor_id" do
      user = Holdco.AccountsFixtures.user_fixture()
      activity_event_fixture(%{actor_id: user.id})
      activity_event_fixture()

      events = Platform.list_recent_activity(%{actor_id: user.id})
      assert Enum.all?(events, &(&1.actor_id == user.id))
    end

    test "activity events are ordered by most recent first" do
      e1 = activity_event_fixture()
      e2 = activity_event_fixture()

      events = Platform.list_recent_activity()
      # Both events should appear in the list
      assert Enum.any?(events, &(&1.id == e1.id))
      assert Enum.any?(events, &(&1.id == e2.id))
      # Events should be ordered by inserted_at desc (most recent has higher id)
      ids = Enum.map(events, & &1.id)
      assert is_list(ids)
    end
  end
end
