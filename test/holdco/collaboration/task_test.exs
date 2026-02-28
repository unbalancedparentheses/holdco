defmodule Holdco.Collaboration.TaskTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Collaboration

  describe "create_task/1" do
    test "creates a task with valid attributes" do
      {:ok, task} = Collaboration.create_task(%{title: "Review Q1 financials"})

      assert task.title == "Review Q1 financials"
      assert task.status == "open"
      assert task.priority == "medium"
    end

    test "creates a task with all fields" do
      company = company_fixture()
      user = user_fixture()

      {:ok, task} =
        Collaboration.create_task(%{
          title: "Prepare board materials",
          description: "Slide deck for board meeting",
          status: "in_progress",
          priority: "high",
          due_date: "2026-03-15",
          linked_entity_type: "meeting",
          linked_entity_id: 1,
          created_from: "meeting",
          notes: "Urgent request from CEO",
          assignee_id: user.id,
          company_id: company.id
        })

      assert task.title == "Prepare board materials"
      assert task.status == "in_progress"
      assert task.priority == "high"
      assert task.due_date == "2026-03-15"
      assert task.created_from == "meeting"
      assert task.assignee_id == user.id
      assert task.company_id == company.id
    end

    test "fails without title" do
      {:error, changeset} = Collaboration.create_task(%{})
      assert changeset.valid? == false
      assert "can't be blank" in errors_on(changeset).title
    end

    test "fails with invalid status" do
      {:error, changeset} = Collaboration.create_task(%{title: "Test", status: "invalid"})
      assert changeset.valid? == false
    end

    test "fails with invalid priority" do
      {:error, changeset} = Collaboration.create_task(%{title: "Test", priority: "super_high"})
      assert changeset.valid? == false
    end

    test "fails with invalid due_date format" do
      {:error, changeset} = Collaboration.create_task(%{title: "Test", due_date: "not-a-date"})
      assert changeset.valid? == false
    end

    test "broadcasts via PubSub" do
      Phoenix.PubSub.subscribe(Holdco.PubSub, "tasks")

      {:ok, task} = Collaboration.create_task(%{title: "PubSub test task"})
      assert_receive {:task_created, ^task}
    end
  end

  describe "get_task!/1" do
    test "returns a task with associations preloaded" do
      company = company_fixture()
      user = user_fixture()
      task = task_fixture(%{company: company, assignee: user})

      fetched = Collaboration.get_task!(task.id)
      assert fetched.id == task.id
      assert Ecto.assoc_loaded?(fetched.assignee)
      assert Ecto.assoc_loaded?(fetched.company)
    end

    test "raises for non-existent task" do
      assert_raise Ecto.NoResultsError, fn -> Collaboration.get_task!(999_999) end
    end
  end

  describe "update_task/2" do
    test "updates a task" do
      task = task_fixture(%{title: "Original title"})
      {:ok, updated} = Collaboration.update_task(task, %{title: "Updated title"})
      assert updated.title == "Updated title"
    end

    test "sets completed_at when completing" do
      task = task_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, updated} = Collaboration.update_task(task, %{status: "completed", completed_at: now})
      assert updated.status == "completed"
      assert updated.completed_at != nil
    end

    test "broadcasts via PubSub" do
      task = task_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "tasks")

      {:ok, updated} = Collaboration.update_task(task, %{title: "Updated"})
      assert_receive {:task_updated, ^updated}
    end

    test "fails with invalid data" do
      task = task_fixture()
      {:error, changeset} = Collaboration.update_task(task, %{title: nil})
      assert changeset.valid? == false
    end
  end

  describe "delete_task/1" do
    test "deletes a task" do
      task = task_fixture()
      {:ok, _} = Collaboration.delete_task(task)
      assert_raise Ecto.NoResultsError, fn -> Collaboration.get_task!(task.id) end
    end

    test "broadcasts via PubSub" do
      task = task_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "tasks")

      {:ok, deleted} = Collaboration.delete_task(task)
      assert_receive {:task_deleted, ^deleted}
    end
  end

  describe "list_tasks/1" do
    test "returns all tasks with no filters" do
      task = task_fixture()
      tasks = Collaboration.list_tasks()
      ids = Enum.map(tasks, & &1.id)
      assert task.id in ids
    end

    test "filters by status" do
      task_fixture(%{title: "Open Task", status: "open"})
      task_fixture(%{title: "Completed Task", status: "completed"})

      tasks = Collaboration.list_tasks(%{status: "open"})
      statuses = Enum.map(tasks, & &1.status)
      assert Enum.all?(statuses, &(&1 == "open"))
    end

    test "filters by priority" do
      task_fixture(%{title: "Urgent Task", priority: "urgent"})
      task_fixture(%{title: "Low Task", priority: "low"})

      tasks = Collaboration.list_tasks(%{priority: "urgent"})
      priorities = Enum.map(tasks, & &1.priority)
      assert Enum.all?(priorities, &(&1 == "urgent"))
    end

    test "filters by company_id" do
      company = company_fixture()
      task_fixture(%{company: company, title: "Company task"})
      task_fixture(%{title: "No company task"})

      tasks = Collaboration.list_tasks(%{company_id: company.id})
      assert Enum.all?(tasks, &(&1.company_id == company.id))
    end

    test "filters by assignee_id" do
      user = user_fixture()
      task_fixture(%{assignee: user, title: "Assigned task"})
      task_fixture(%{title: "Unassigned task"})

      tasks = Collaboration.list_tasks(%{assignee_id: user.id})
      assert Enum.all?(tasks, &(&1.assignee_id == user.id))
    end

    test "returns empty list when no tasks match filters" do
      task_fixture(%{status: "open"})
      tasks = Collaboration.list_tasks(%{status: "cancelled"})
      assert tasks == []
    end

    test "ignores empty string filters" do
      task = task_fixture()
      tasks = Collaboration.list_tasks(%{status: "", priority: ""})
      ids = Enum.map(tasks, & &1.id)
      assert task.id in ids
    end
  end

  describe "list_tasks_for_user/1" do
    test "returns tasks for a specific user" do
      user = user_fixture()
      task1 = task_fixture(%{assignee: user, title: "User task 1"})
      task2 = task_fixture(%{assignee: user, title: "User task 2"})
      task_fixture(%{title: "Other task"})

      tasks = Collaboration.list_tasks_for_user(user.id)
      ids = Enum.map(tasks, & &1.id)
      assert task1.id in ids
      assert task2.id in ids
      assert length(tasks) == 2
    end

    test "returns empty list for user with no tasks" do
      user = user_fixture()
      tasks = Collaboration.list_tasks_for_user(user.id)
      assert tasks == []
    end
  end

  describe "list_overdue_tasks/0" do
    test "returns tasks past due date with open/in_progress status" do
      yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()
      overdue = task_fixture(%{title: "Overdue task", due_date: yesterday, status: "open"})

      tasks = Collaboration.list_overdue_tasks()
      ids = Enum.map(tasks, & &1.id)
      assert overdue.id in ids
    end

    test "excludes completed tasks even if past due" do
      yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()
      task_fixture(%{title: "Done task", due_date: yesterday, status: "completed"})

      tasks = Collaboration.list_overdue_tasks()
      assert tasks == []
    end

    test "excludes tasks with future due dates" do
      tomorrow = Date.utc_today() |> Date.add(1) |> Date.to_string()
      task_fixture(%{title: "Future task", due_date: tomorrow, status: "open"})

      tasks = Collaboration.list_overdue_tasks()
      assert tasks == []
    end

    test "excludes tasks with no due date" do
      task_fixture(%{title: "No date task", status: "open"})

      tasks = Collaboration.list_overdue_tasks()
      assert tasks == []
    end

    test "includes in_progress tasks past due" do
      yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()
      overdue = task_fixture(%{title: "WIP overdue", due_date: yesterday, status: "in_progress"})

      tasks = Collaboration.list_overdue_tasks()
      ids = Enum.map(tasks, & &1.id)
      assert overdue.id in ids
    end
  end
end
