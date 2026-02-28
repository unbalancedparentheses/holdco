defmodule Holdco.Notifications.Dispatcher do
  @moduledoc """
  Dispatches notifications to configured channels.

  Finds active channels for a user, filters by event type,
  creates delivery records, and attempts to send via the appropriate provider.
  """

  alias Holdco.Notifications

  @providers %{
    "slack" => Holdco.Notifications.Providers.Slack,
    "telegram" => Holdco.Notifications.Providers.Telegram,
    "email" => Holdco.Notifications.Providers.Email
  }

  @doc """
  Dispatch a notification to all active channels for its user that match the event_type.

  Returns `{sent_count, failed_count}`.
  """
  def dispatch(notification, event_type \\ "system") do
    channels = Notifications.list_active_channels_for_user(notification.user_id, event_type)

    results =
      Enum.map(channels, fn channel ->
        # Skip in_app channels — those are handled by the existing notification system
        if channel.provider == "in_app" do
          {:skipped, channel}
        else
          deliver_to_channel(notification, channel)
        end
      end)

    sent_count = Enum.count(results, fn {status, _} -> status == :ok end)
    failed_count = Enum.count(results, fn {status, _} -> status == :error end)

    {sent_count, failed_count}
  end

  @doc """
  Broadcast a notification to all users who have channels subscribed to the given event_type.

  Creates a notification for each user and dispatches it.
  Returns a list of `{notification, {sent, failed}}` tuples.
  """
  def dispatch_to_all_users(title, body, event_type, opts \\ []) do
    type = Keyword.get(opts, :type, "info")
    entity_type = Keyword.get(opts, :entity_type)
    entity_id = Keyword.get(opts, :entity_id)
    action_url = Keyword.get(opts, :action_url)

    user_ids = Notifications.user_ids_with_active_channels(event_type)

    Enum.map(user_ids, fn user_id ->
      {:ok, notification} =
        Notifications.create_notification(%{
          user_id: user_id,
          title: title,
          body: body,
          type: type,
          entity_type: entity_type,
          entity_id: entity_id,
          action_url: action_url
        })

      result = dispatch(notification, event_type)
      {notification, result}
    end)
  end

  @doc """
  Returns the provider module for the given provider name.
  """
  def get_provider(name), do: Map.get(@providers, name)

  @doc """
  Returns a list of all available provider names.
  """
  def available_providers, do: Map.keys(@providers)

  # Private helpers

  defp deliver_to_channel(notification, channel) do
    provider_mod = get_provider(channel.provider)

    {:ok, delivery} =
      Notifications.create_delivery(%{
        notification_id: notification.id,
        channel_id: channel.id,
        provider: channel.provider,
        status: "pending",
        attempts: 0
      })

    if provider_mod do
      attempt_send(delivery, provider_mod, channel, notification)
    else
      {:ok, _} =
        Notifications.update_delivery(delivery, %{
          status: "failed",
          error_message: "Unknown provider: #{channel.provider}",
          attempts: 1
        })

      {:error, delivery}
    end
  end

  defp attempt_send(delivery, provider_mod, channel, notification) do
    case provider_mod.send_notification(channel, notification) do
      {:ok, _result} ->
        {:ok, updated} =
          Notifications.update_delivery(delivery, %{
            status: "sent",
            sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
            attempts: delivery.attempts + 1
          })

        {:ok, updated}

      {:error, error_message} ->
        {:ok, updated} =
          Notifications.update_delivery(delivery, %{
            status: "failed",
            error_message: error_message,
            attempts: delivery.attempts + 1
          })

        {:error, updated}
    end
  end
end
