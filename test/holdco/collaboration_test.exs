defmodule Holdco.CollaborationTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Collaboration

  describe "comments" do
    test "create_comment/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      {:ok, c} = Collaboration.create_comment(%{user_id: user.id, entity_type: "company", entity_id: 1, body: "Great job!"})
      assert c.body == "Great job!"
    end

    test "list_comments/2" do
      user = Holdco.AccountsFixtures.user_fixture()
      comment_fixture(%{user: user, entity_type: "company", entity_id: 42})
      assert length(Collaboration.list_comments("company", 42)) > 0
    end

    test "recent_comments/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      comment_fixture(%{user: user})
      assert length(Collaboration.recent_comments(%{})) > 0
    end

    test "comment_count/2" do
      user = Holdco.AccountsFixtures.user_fixture()
      comment_fixture(%{user: user, entity_type: "holding", entity_id: 99})
      assert Collaboration.comment_count("holding", 99) >= 1
    end

    test "delete_comment/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      c = comment_fixture(%{user: user})
      {:ok, _} = Collaboration.delete_comment(c)
    end

    test "list_comments/2 returns comments in ascending order" do
      user = Holdco.AccountsFixtures.user_fixture()
      c1 = comment_fixture(%{user: user, entity_type: "holding", entity_id: 10, body: "First"})
      c2 = comment_fixture(%{user: user, entity_type: "holding", entity_id: 10, body: "Second"})

      comments = Collaboration.list_comments("holding", 10)
      ids = Enum.map(comments, & &1.id)
      assert List.first(ids) == c1.id
      assert List.last(ids) == c2.id
    end

    test "list_comments/2 returns empty for non-existent entity" do
      assert Collaboration.list_comments("nonexistent", 999) == []
    end

    test "list_comments/2 preloads user association" do
      user = Holdco.AccountsFixtures.user_fixture()
      comment_fixture(%{user: user, entity_type: "company", entity_id: 77})

      [comment | _] = Collaboration.list_comments("company", 77)
      assert comment.user != nil
      assert comment.user.email == user.email
    end

    test "recent_comments/1 respects limit option" do
      user = Holdco.AccountsFixtures.user_fixture()

      for i <- 1..5 do
        comment_fixture(%{user: user, body: "Comment #{i}"})
      end

      comments = Collaboration.recent_comments(%{limit: 3})
      assert length(comments) == 3
    end

    test "recent_comments/1 returns all matching comments" do
      user = Holdco.AccountsFixtures.user_fixture()
      c1 = comment_fixture(%{user: user, entity_type: "company", entity_id: 200, body: "Comment A"})
      c2 = comment_fixture(%{user: user, entity_type: "company", entity_id: 201, body: "Comment B"})

      comments = Collaboration.recent_comments(%{limit: 10})
      ids = Enum.map(comments, & &1.id)
      assert c1.id in ids
      assert c2.id in ids
    end

    test "comment_count/2 returns 0 for entity with no comments" do
      assert Collaboration.comment_count("company", 999_999) == 0
    end

    test "create_comment/1 broadcasts via PubSub" do
      user = Holdco.AccountsFixtures.user_fixture()

      Phoenix.PubSub.subscribe(Holdco.PubSub, "comments:company:55")

      {:ok, comment} =
        Collaboration.create_comment(%{
          user_id: user.id,
          entity_type: "company",
          entity_id: 55,
          body: "PubSub test"
        })

      assert_receive {:new_comment, ^comment}
    end

    test "create_comment/1 with missing required fields returns error" do
      {:error, changeset} = Collaboration.create_comment(%{})
      assert changeset.valid? == false
    end
  end
end
