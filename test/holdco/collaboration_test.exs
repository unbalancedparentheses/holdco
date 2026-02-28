defmodule Holdco.CollaborationTest do
  use Holdco.DataCase, async: true

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

  describe "contacts" do
    test "list_contacts/0 returns all contacts" do
      contact = contact_fixture()
      contacts = Collaboration.list_contacts()
      ids = Enum.map(contacts, & &1.id)
      assert contact.id in ids
    end

    test "list_contacts/1 with empty opts returns all contacts" do
      contact_fixture(%{name: "Alice Wonderland"})
      contact_fixture(%{name: "Bob Builder"})

      contacts = Collaboration.list_contacts(%{})
      names = Enum.map(contacts, & &1.name)
      assert "Alice Wonderland" in names
      assert "Bob Builder" in names
    end

    test "list_contacts/1 with nil search returns all contacts" do
      contact_fixture(%{name: "NilSearchContact"})
      contacts = Collaboration.list_contacts(%{search: nil})
      names = Enum.map(contacts, & &1.name)
      assert "NilSearchContact" in names
    end

    test "list_contacts/1 with empty search returns all contacts" do
      contact_fixture(%{name: "EmptySearchContact"})
      contacts = Collaboration.list_contacts(%{search: ""})
      names = Enum.map(contacts, & &1.name)
      assert "EmptySearchContact" in names
    end

    test "get_contact!/1 returns a contact with companies preloaded" do
      contact = contact_fixture()
      fetched = Collaboration.get_contact!(contact.id)
      assert fetched.id == contact.id
      assert Ecto.assoc_loaded?(fetched.companies)
    end

    test "create_contact/1 creates a contact" do
      {:ok, contact} =
        Collaboration.create_contact(%{
          name: "New Contact",
          title: "CEO",
          organization: "Test Corp",
          email: "new@example.com",
          phone: "+1-555-0001",
          role_tag: "investor"
        })

      assert contact.name == "New Contact"
      assert contact.title == "CEO"
    end

    test "create_contact/1 broadcasts via PubSub" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "contacts")

      {:ok, contact} =
        Collaboration.create_contact(%{
          name: "PubSub Contact",
          email: "pubsub@example.com"
        })

      assert_receive {:contact_created, ^contact}
    end

    test "create_contact/1 with invalid data returns error" do
      {:error, changeset} = Collaboration.create_contact(%{})
      assert changeset.valid? == false
    end

    test "update_contact/2 updates a contact" do
      contact = contact_fixture(%{name: "Old Name"})
      {:ok, updated} = Collaboration.update_contact(contact, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "update_contact/2 broadcasts via PubSub" do
      contact = contact_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "contacts")

      {:ok, updated} = Collaboration.update_contact(contact, %{name: "Updated Contact"})
      assert_receive {:contact_updated, ^updated}
    end

    test "update_contact/2 with invalid data returns error" do
      contact = contact_fixture()
      {:error, changeset} = Collaboration.update_contact(contact, %{name: nil})
      assert changeset.valid? == false
    end

    test "delete_contact/1 deletes a contact" do
      contact = contact_fixture()
      {:ok, _} = Collaboration.delete_contact(contact)
      assert_raise Ecto.NoResultsError, fn -> Collaboration.get_contact!(contact.id) end
    end

    test "delete_contact/1 broadcasts via PubSub" do
      contact = contact_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "contacts")

      {:ok, deleted} = Collaboration.delete_contact(contact)
      assert_receive {:contact_deleted, ^deleted}
    end
  end

  describe "projects" do
    test "list_projects/0 returns all projects" do
      project = project_fixture()
      projects = Collaboration.list_projects()
      ids = Enum.map(projects, & &1.id)
      assert project.id in ids
    end

    test "list_projects/1 filters by status" do
      project_fixture(%{name: "Active Project", status: "active"})
      project_fixture(%{name: "Planned Project", status: "planned"})

      projects = Collaboration.list_projects(%{status: "active"})
      statuses = Enum.map(projects, & &1.status)
      assert Enum.all?(statuses, &(&1 == "active"))
    end

    test "list_projects/1 with nil status returns all projects" do
      project_fixture(%{name: "NilStatusProject"})
      projects = Collaboration.list_projects(%{status: nil})
      names = Enum.map(projects, & &1.name)
      assert "NilStatusProject" in names
    end

    test "list_projects/1 with empty status returns all projects" do
      project_fixture(%{name: "EmptyStatusProject"})
      projects = Collaboration.list_projects(%{status: ""})
      names = Enum.map(projects, & &1.name)
      assert "EmptyStatusProject" in names
    end

    test "get_project!/1 returns a project with associations preloaded" do
      project = project_fixture()
      fetched = Collaboration.get_project!(project.id)
      assert fetched.id == project.id
      assert Ecto.assoc_loaded?(fetched.contact)
      assert Ecto.assoc_loaded?(fetched.companies)
    end

    test "create_project/1 creates a project" do
      {:ok, project} =
        Collaboration.create_project(%{
          name: "New Project",
          status: "active",
          project_type: "acquisition",
          description: "A new project"
        })

      assert project.name == "New Project"
      assert project.status == "active"
    end

    test "create_project/1 broadcasts via PubSub" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "projects")

      {:ok, project} =
        Collaboration.create_project(%{
          name: "PubSub Project",
          status: "planned",
          project_type: "fundraise"
        })

      assert_receive {:project_created, ^project}
    end

    test "create_project/1 with invalid data returns error" do
      {:error, changeset} = Collaboration.create_project(%{})
      assert changeset.valid? == false
    end

    test "update_project/2 updates a project" do
      project = project_fixture(%{name: "Old Project"})
      {:ok, updated} = Collaboration.update_project(project, %{name: "Updated Project"})
      assert updated.name == "Updated Project"
    end

    test "update_project/2 broadcasts via PubSub" do
      project = project_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "projects")

      {:ok, updated} = Collaboration.update_project(project, %{name: "Updated"})
      assert_receive {:project_updated, ^updated}
    end

    test "update_project/2 with invalid data returns error" do
      project = project_fixture()
      {:error, changeset} = Collaboration.update_project(project, %{name: nil})
      assert changeset.valid? == false
    end

    test "delete_project/1 deletes a project" do
      project = project_fixture()
      {:ok, _} = Collaboration.delete_project(project)
      assert_raise Ecto.NoResultsError, fn -> Collaboration.get_project!(project.id) end
    end

    test "delete_project/1 broadcasts via PubSub" do
      project = project_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "projects")

      {:ok, deleted} = Collaboration.delete_project(project)
      assert_receive {:project_deleted, ^deleted}
    end
  end
end
