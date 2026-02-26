defmodule Holdco.Collaboration do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Collaboration.Comment
  alias Holdco.Collaboration.Contact
  alias Holdco.Collaboration.Project

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

  # --- Projects ---

  def list_projects(opts \\ %{}) do
    query = from(p in Project, order_by: [asc: p.name], preload: [:contact, :companies])

    query =
      case Map.get(opts, :status) do
        nil -> query
        "" -> query
        status -> from(p in query, where: p.status == ^status)
      end

    Repo.all(query)
  end

  def get_project!(id) do
    Project
    |> Repo.get!(id)
    |> Repo.preload([:contact, :companies])
  end

  def create_project(attrs) do
    %Project{}
    |> Project.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, project} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "projects",
          {:project_created, project}
        )

      _ ->
        :ok
    end)
  end

  def update_project(%Project{} = project, attrs) do
    project
    |> Project.changeset(attrs)
    |> Repo.update()
    |> tap(fn
      {:ok, project} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "projects",
          {:project_updated, project}
        )

      _ ->
        :ok
    end)
  end

  def delete_project(%Project{} = project) do
    Repo.delete(project)
    |> tap(fn
      {:ok, project} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "projects",
          {:project_deleted, project}
        )

      _ ->
        :ok
    end)
  end
end
