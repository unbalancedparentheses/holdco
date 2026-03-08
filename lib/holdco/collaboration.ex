defmodule Holdco.Collaboration do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Collaboration.Comment
  alias Holdco.Collaboration.Contact
  alias Holdco.Collaboration.ContactInteraction
  alias Holdco.Collaboration.Task

  def list_comments(entity_type, entity_id) do
    from(c in Comment,
      where: c.entity_type == ^entity_type and c.entity_id == ^entity_id,
      order_by: [asc: c.inserted_at],
      preload: [:user]
    )
    |> Repo.all()
  end

  def recent_comments(opts \\ %{}) do
    limit = Map.get(opts, :limit, 20)

    from(c in Comment,
      order_by: [desc: c.inserted_at],
      limit: ^limit,
      preload: [:user]
    )
    |> Repo.all()
  end

  def create_comment(attrs) do
    %Comment{}
    |> Comment.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, comment} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "comments:#{comment.entity_type}:#{comment.entity_id}",
          {:new_comment, comment}
        )

      _ ->
        :ok
    end)
  end

  def delete_comment(%Comment{} = comment), do: Repo.delete(comment)

  def comment_count(entity_type, entity_id) do
    from(c in Comment,
      where: c.entity_type == ^entity_type and c.entity_id == ^entity_id,
      select: count(c.id)
    )
    |> Repo.one()
  end

  # --- Contacts ---

  def list_contacts(opts \\ %{}) do
    query = from(c in Contact, order_by: [asc: c.name])

    query =
      case Map.get(opts, :search) do
        nil -> query
        "" -> query
        term -> from(c in query, where: ilike(c.name, ^"%#{term}%"))
      end

    Repo.all(query)
  end

  def get_contact!(id) do
    Contact
    |> Repo.get!(id)
    |> Repo.preload(:companies)
  end

  def create_contact(attrs) do
    %Contact{}
    |> Contact.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, contact} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "contacts",
          {:contact_created, contact}
        )

      _ ->
        :ok
    end)
  end

  def update_contact(%Contact{} = contact, attrs) do
    contact
    |> Contact.changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, contact} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "contacts",
          {:contact_updated, contact}
        )

      _ ->
        :ok
    end)
  end

  def delete_contact(%Contact{} = contact) do
    Repo.delete(contact)
    |> tap(fn
      {:ok, contact} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "contacts",
          {:contact_deleted, contact}
        )

      _ ->
        :ok
    end)
  end

  # --- Contact Interactions ---

  def list_interactions(contact_id) do
    from(i in ContactInteraction,
      where: i.contact_id == ^contact_id,
      order_by: [desc: i.date, desc: i.inserted_at]
    )
    |> Repo.all()
  end

  def create_interaction(attrs) do
    %ContactInteraction{}
    |> ContactInteraction.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("contact_interactions", "create")
  end

  def delete_interaction(%ContactInteraction{} = interaction) do
    Repo.delete(interaction)
    |> audit_and_broadcast("contact_interactions", "delete")
  end

  def get_interaction!(id), do: Repo.get!(ContactInteraction, id)

  # --- Tasks ---

  def subscribe_tasks do
    Phoenix.PubSub.subscribe(Holdco.PubSub, "tasks")
  end

  def list_tasks(opts \\ %{}) do
    query = from(t in Task, order_by: [asc: t.due_date, desc: t.inserted_at], preload: [:assignee, :company])

    query =
      case Map.get(opts, :company_id) do
        nil -> query
        "" -> query
        id -> from(t in query, where: t.company_id == ^id)
      end

    query =
      case Map.get(opts, :status) do
        nil -> query
        "" -> query
        status -> from(t in query, where: t.status == ^status)
      end

    query =
      case Map.get(opts, :priority) do
        nil -> query
        "" -> query
        priority -> from(t in query, where: t.priority == ^priority)
      end

    query =
      case Map.get(opts, :assignee_id) do
        nil -> query
        "" -> query
        assignee_id -> from(t in query, where: t.assignee_id == ^assignee_id)
      end

    Repo.all(query)
  end

  def get_task!(id) do
    Task
    |> Repo.get!(id)
    |> Repo.preload([:assignee, :company])
  end

  def create_task(attrs) do
    %Task{}
    |> Task.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, task} ->
        Holdco.Platform.log_action("create", "tasks", task.id)

        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "tasks",
          {:task_created, task}
        )

      _ ->
        :ok
    end)
  end

  def update_task(%Task{} = task, attrs) do
    task
    |> Task.changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, task} ->
        Holdco.Platform.log_action("update", "tasks", task.id)

        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "tasks",
          {:task_updated, task}
        )

      _ ->
        :ok
    end)
  end

  def delete_task(%Task{} = task) do
    Repo.delete(task)
    |> tap(fn
      {:ok, task} ->
        Holdco.Platform.log_action("delete", "tasks", task.id)

        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "tasks",
          {:task_deleted, task}
        )

      _ ->
        :ok
    end)
  end

  def list_tasks_for_user(assignee_id) do
    from(t in Task,
      where: t.assignee_id == ^assignee_id,
      order_by: [asc: t.due_date, desc: t.inserted_at],
      preload: [:assignee, :company]
    )
    |> Repo.all()
  end

  def list_overdue_tasks do
    today = Date.utc_today() |> Date.to_string()

    from(t in Task,
      where: t.status in ["open", "in_progress"] and not is_nil(t.due_date) and t.due_date < ^today,
      order_by: [asc: t.due_date],
      preload: [:assignee, :company]
    )
    |> Repo.all()
  end

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        {:ok, record}

      error ->
        error
    end
  end
end
