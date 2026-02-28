defmodule Holdco.Platform.CollaborationSessionTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Platform

  describe "collaboration_sessions CRUD" do
    test "list_active_sessions/2 returns active sessions for entity" do
      session = collaboration_session_fixture()
      results = Platform.list_active_sessions(session.entity_type, session.entity_id)
      assert Enum.any?(results, &(&1.id == session.id))
    end

    test "list_active_sessions/2 does not return inactive sessions" do
      session = collaboration_session_fixture()
      {:ok, _} = Platform.end_session(session)
      results = Platform.list_active_sessions(session.entity_type, session.entity_id)
      refute Enum.any?(results, &(&1.id == session.id))
    end

    test "list_active_sessions/2 filters by entity_type and entity_id" do
      session = collaboration_session_fixture(%{entity_type: "company", entity_id: 999})
      other = collaboration_session_fixture(%{entity_type: "document", entity_id: 999})

      results = Platform.list_active_sessions("company", 999)
      assert Enum.any?(results, &(&1.id == session.id))
      refute Enum.any?(results, &(&1.id == other.id))
    end

    test "list_all_active_sessions/0 returns all active sessions" do
      session = collaboration_session_fixture()
      results = Platform.list_all_active_sessions()
      assert Enum.any?(results, &(&1.id == session.id))
    end

    test "get_collaboration_session!/1 returns the session with preloads" do
      session = collaboration_session_fixture()
      fetched = Platform.get_collaboration_session!(session.id)
      assert fetched.id == session.id
      assert fetched.user != nil
    end

    test "get_collaboration_session!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_collaboration_session!(0)
      end
    end

    test "create_session/1 with valid data" do
      user = user_fixture()

      assert {:ok, session} =
               Platform.create_session(%{
                 entity_type: "company",
                 entity_id: 42,
                 user_id: user.id
               })

      assert session.entity_type == "company"
      assert session.entity_id == 42
      assert session.is_active == true
      assert session.started_at != nil
      assert session.last_active_at != nil
    end

    test "create_session/1 fails without required fields" do
      assert {:error, changeset} = Platform.create_session(%{})
      errors = errors_on(changeset)
      assert errors[:entity_type]
      assert errors[:entity_id]
      assert errors[:user_id]
    end

    test "update_session/2 with valid data" do
      session = collaboration_session_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      assert {:ok, updated} =
               Platform.update_session(session, %{
                 last_active_at: now,
                 notes: [%{"text" => "Working on review", "at" => DateTime.to_iso8601(now)}]
               })

      assert updated.last_active_at == now
      assert length(updated.notes) == 1
    end

    test "end_session/1 marks session as inactive" do
      session = collaboration_session_fixture()
      assert session.is_active == true

      assert {:ok, ended} = Platform.end_session(session)
      assert ended.is_active == false
    end
  end

  describe "active_users_on_entity/2" do
    test "returns users with active sessions on entity" do
      user = user_fixture()
      _session = collaboration_session_fixture(%{user: user, entity_type: "company", entity_id: 100})

      users = Platform.active_users_on_entity("company", 100)
      assert Enum.any?(users, &(&1.id == user.id))
    end

    test "does not return users with ended sessions" do
      user = user_fixture()
      session = collaboration_session_fixture(%{user: user, entity_type: "company", entity_id: 101})
      {:ok, _} = Platform.end_session(session)

      users = Platform.active_users_on_entity("company", 101)
      refute Enum.any?(users, &(&1.id == user.id))
    end

    test "returns multiple users on same entity" do
      user1 = user_fixture()
      user2 = user_fixture()
      _s1 = collaboration_session_fixture(%{user: user1, entity_type: "document", entity_id: 200})
      _s2 = collaboration_session_fixture(%{user: user2, entity_type: "document", entity_id: 200})

      users = Platform.active_users_on_entity("document", 200)
      user_ids = Enum.map(users, & &1.id)
      assert user1.id in user_ids
      assert user2.id in user_ids
    end
  end

  describe "session defaults" do
    test "started_at and last_active_at are set automatically" do
      user = user_fixture()

      {:ok, session} =
        Platform.create_session(%{
          entity_type: "holding",
          entity_id: 1,
          user_id: user.id
        })

      assert session.started_at != nil
      assert session.last_active_at != nil
    end

    test "is_active defaults to true" do
      user = user_fixture()

      {:ok, session} =
        Platform.create_session(%{
          entity_type: "holding",
          entity_id: 1,
          user_id: user.id
        })

      assert session.is_active == true
    end

    test "notes defaults to empty array" do
      user = user_fixture()

      {:ok, session} =
        Platform.create_session(%{
          entity_type: "holding",
          entity_id: 1,
          user_id: user.id
        })

      assert session.notes == []
    end
  end
end
