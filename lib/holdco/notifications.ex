defmodule Holdco.Notifications do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Notifications.Notification
  alias Holdco.Notifications.NotificationChannel
  alias Holdco.Notifications.NotificationDelivery

  # ── Notifications (existing) ────────────────────────────────────

  def list_notifications(user_id, opts \\ %{}) do
    limit = Map.get(opts, :limit, 50)

    from(n in Notification,
      where: n.user_id == ^user_id,
      order_by: [desc: n.inserted_at],
      limit: ^limit
    )
    |> Repo.all()
  end

  def list_unread_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      order_by: [desc: n.inserted_at]
    )
    |> Repo.all()
  end

  def count_unread_notifications(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at),
      select: count(n.id)
    )
    |> Repo.one()
  end

  # Keep the old name as an alias for backward compatibility
  def unread_count(user_id), do: count_unread_notifications(user_id)

  def create_notification(attrs) do
    %Notification{}
    |> Notification.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, notif} ->
        broadcast(notif.user_id, {:new_notification, notif})

      _ ->
        :ok
    end)
  end

  def mark_as_read(%Notification{} = notification) do
    notification
    |> Ecto.Changeset.change(read_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end

  # Keep old name for backward compatibility
  def mark_read(notification_id) do
    Repo.get!(Notification, notification_id)
    |> mark_as_read()
  end

  def mark_all_as_read(user_id) do
    from(n in Notification,
      where: n.user_id == ^user_id and is_nil(n.read_at)
    )
    |> Repo.update_all(set: [read_at: DateTime.utc_now() |> DateTime.truncate(:second)])
  end

  # Keep old name for backward compatibility
  def mark_all_read(user_id), do: mark_all_as_read(user_id)

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

  # ── Channels ────────────────────────────────────────────────────

  def list_channels(user_id) do
    from(c in NotificationChannel,
      where: c.user_id == ^user_id,
      order_by: [asc: c.provider, desc: c.inserted_at]
    )
    |> Repo.all()
  end

  def get_channel!(id), do: Repo.get!(NotificationChannel, id)

  def create_channel(attrs) do
    %NotificationChannel{}
    |> NotificationChannel.changeset(attrs)
    |> Repo.insert()
  end

  def update_channel(%NotificationChannel{} = channel, attrs) do
    channel
    |> NotificationChannel.changeset(attrs)
    |> Repo.update()
  end

  def delete_channel(%NotificationChannel{} = channel) do
    Repo.delete(channel)
  end

  def list_active_channels_for_user(user_id, event_type \\ nil) do
    query =
      from(c in NotificationChannel,
        where: c.user_id == ^user_id and c.is_active == true
      )

    query =
      if event_type do
        from(c in query, where: ^event_type in c.event_types or c.event_types == ^[])
      else
        query
      end

    Repo.all(query)
  end

  @doc """
  Returns distinct user IDs that have at least one active channel matching the given event_type.
  """
  def user_ids_with_active_channels(event_type) do
    from(c in NotificationChannel,
      where: c.is_active == true,
      where: ^event_type in c.event_types or c.event_types == ^[],
      select: c.user_id,
      distinct: true
    )
    |> Repo.all()
  end

  # ── Deliveries ──────────────────────────────────────────────────

  def list_deliveries(notification_id) do
    from(d in NotificationDelivery,
      where: d.notification_id == ^notification_id,
      order_by: [desc: d.inserted_at],
      preload: [:channel]
    )
    |> Repo.all()
  end

  def list_recent_deliveries(user_id, limit \\ 50) do
    from(d in NotificationDelivery,
      join: n in Notification,
      on: d.notification_id == n.id,
      where: n.user_id == ^user_id,
      order_by: [desc: d.inserted_at],
      limit: ^limit,
      preload: [:notification, :channel]
    )
    |> Repo.all()
  end

  def create_delivery(attrs) do
    %NotificationDelivery{}
    |> NotificationDelivery.changeset(attrs)
    |> Repo.insert()
  end

  def update_delivery(%NotificationDelivery{} = delivery, attrs) do
    delivery
    |> NotificationDelivery.changeset(attrs)
    |> Repo.update()
  end

  def delivery_stats(user_id) do
    from(d in NotificationDelivery,
      join: n in Notification,
      on: d.notification_id == n.id,
      where: n.user_id == ^user_id,
      select: %{
        total: count(d.id),
        sent: count(fragment("CASE WHEN ? = 'sent' THEN 1 END", d.status)),
        failed: count(fragment("CASE WHEN ? = 'failed' THEN 1 END", d.status))
      }
    )
    |> Repo.one()
    |> case do
      nil -> %{total: 0, sent: 0, failed: 0}
      stats -> stats
    end
  end

  # ── PubSub ──────────────────────────────────────────────────────

  def subscribe(user_id) do
    Phoenix.PubSub.subscribe(Holdco.PubSub, "notifications:#{user_id}")
  end

  defp broadcast(user_id, message) do
    Phoenix.PubSub.broadcast(Holdco.PubSub, "notifications:#{user_id}", message)
  end
end
