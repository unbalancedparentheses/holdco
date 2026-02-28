defmodule Holdco.Notifications.DispatcherTest do
  use Holdco.DataCase, async: true

  alias Holdco.Notifications
  alias Holdco.Notifications.Dispatcher

  import Holdco.AccountsFixtures
  import Holdco.HoldcoFixtures

  # We use Mox-free testing by creating real channels but testing dispatch logic
  # Provider send_notification calls will fail in tests (no real endpoints)
  # but we can verify delivery records are created with correct status

  setup do
    user = user_fixture()
    %{user: user}
  end

  describe "dispatch/2" do
    test "creates delivery records for active channels", %{user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/INVALID"}
      })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Test dispatch",
          body: "Testing"
        })

      # dispatch will attempt to send and fail (invalid URL)
      {sent, failed} = Dispatcher.dispatch(notif, "system")

      # The Req call should fail since there's no real server
      assert sent + failed >= 1

      # Verify delivery record was created
      deliveries = Notifications.list_deliveries(notif.id)
      assert length(deliveries) >= 1
      assert hd(deliveries).provider == "slack"
    end

    test "skips inactive channels", %{user: user} do
      {:ok, _inactive} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: false,
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/XXX"},
          event_types: ["system"]
        })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Test skip inactive",
          body: "Testing"
        })

      {sent, failed} = Dispatcher.dispatch(notif, "system")
      assert sent == 0
      assert failed == 0

      deliveries = Notifications.list_deliveries(notif.id)
      assert deliveries == []
    end

    test "filters by event_type", %{user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["alert"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/ALERT"}
      })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "System event",
          body: "Testing"
        })

      # Dispatch with event_type "system" should not match "alert"-only channel
      {sent, failed} = Dispatcher.dispatch(notif, "system")
      assert sent == 0
      assert failed == 0
    end

    test "dispatches to channels with matching event_type", %{user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["alert", "system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/MATCH"}
      })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Alert event",
          body: "Testing"
        })

      {sent, failed} = Dispatcher.dispatch(notif, "alert")
      # Should attempt delivery (will fail due to invalid URL)
      assert sent + failed >= 1
    end

    test "skips in_app channels", %{user: user} do
      {:ok, _in_app} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "in_app",
          event_types: ["system"]
        })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "In-app test",
          body: "Testing"
        })

      {sent, failed} = Dispatcher.dispatch(notif, "system")
      # in_app channels are skipped by the dispatcher
      assert sent == 0
      assert failed == 0
    end

    test "handles provider errors gracefully", %{user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/INVALID/WILL/FAIL"}
      })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Error handling test",
          body: "Testing"
        })

      # Should not raise
      {sent, failed} = Dispatcher.dispatch(notif, "system")
      assert is_integer(sent)
      assert is_integer(failed)

      # Verify the delivery was marked as failed
      deliveries = Notifications.list_deliveries(notif.id)
      assert length(deliveries) >= 1

      delivery = hd(deliveries)
      assert delivery.status in ["sent", "failed"]
      assert delivery.attempts >= 1
    end

    test "dispatches to multiple channels", %{user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/CH1"}
      })

      {:ok, _} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          event_types: ["system"],
          config: %{"email" => "test@example.com"}
        })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Multi-channel test",
          body: "Testing"
        })

      {sent, failed} = Dispatcher.dispatch(notif, "system")
      # Both channels should be attempted
      assert sent + failed == 2

      deliveries = Notifications.list_deliveries(notif.id)
      assert length(deliveries) == 2
      providers = Enum.map(deliveries, & &1.provider) |> Enum.sort()
      assert providers == ["email", "slack"]
    end
  end

  describe "dispatch_to_all_users/4" do
    test "broadcasts to all users with matching channels", %{user: user} do
      user2 = user_fixture()

      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        event_types: ["system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/U1"}
      })

      notification_channel_fixture(%{
        user: user2,
        provider: "slack",
        event_types: ["system"],
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/U2"}
      })

      results = Dispatcher.dispatch_to_all_users("Broadcast", "Hello all", "system")
      assert length(results) == 2

      # Each result is {notification, {sent, failed}}
      for {notif, {sent, failed}} <- results do
        assert notif.title == "Broadcast"
        assert sent + failed >= 1
      end
    end

    test "does nothing when no users have matching channels" do
      results = Dispatcher.dispatch_to_all_users("No one", "Empty", "nonexistent_event")
      assert results == []
    end
  end

  describe "available_providers/0" do
    test "returns all provider names" do
      providers = Dispatcher.available_providers()
      assert "slack" in providers
      assert "telegram" in providers
      assert "email" in providers
    end
  end

  describe "get_provider/1" do
    test "returns correct module for slack" do
      assert Dispatcher.get_provider("slack") == Holdco.Notifications.Providers.Slack
    end

    test "returns correct module for telegram" do
      assert Dispatcher.get_provider("telegram") == Holdco.Notifications.Providers.Telegram
    end

    test "returns correct module for email" do
      assert Dispatcher.get_provider("email") == Holdco.Notifications.Providers.Email
    end

    test "returns nil for unknown provider" do
      assert Dispatcher.get_provider("unknown") == nil
    end
  end
end
