defmodule Holdco.Notifications do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Notifications.Notification

  def list_notifications(user_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 50)

    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def unread_count(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end

  def mark_read(notification_id) do
    Repo.get!(Notification, notification_id)
    |> Ecto.Changeset.change(read_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  def mark_all_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, notif} ->
        Phoenix.PubSub.broadcast(
          Holdco.PubSub,
          "notifications:#{notif.user_id}",
          {:new_notification, notif}
        )

      _ ->
        :ok
    end)
  end

  def delete_notification(%Notification{} = notif), do: Repo.delete(notif)

  def notify_all_admins(title, body, opts \\ []) do
    import Ecto.Query
    alias Holdco.Accounts.UserRole

    admin_ids =
      from(r in UserRole, where: r.role == "admin", select: r.user_id)
      |> Repo.all()

    for user_id <- admin_ids do
      create_notification(
        Map.merge(
          %{user_id: user_id, title: title, body: body},
          Map.new(opts)
        )
      )
    end
  end
end
