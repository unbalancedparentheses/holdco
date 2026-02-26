defmodule Holdco.Collaboration do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Collaboration.Comment

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
end
