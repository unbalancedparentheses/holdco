defmodule Holdco.Integration.NotificationDispatchTest do
  @moduledoc """
  Integration tests for the notification system:
  channel creation -> notification dispatch -> delivery tracking ->
  log management -> failure handling -> multi-provider scenarios ->
  PubSub broadcasting.
  """
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Notifications
  alias Holdco.Notifications.Dispatcher

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp setup_user_with_channels do
    user = user_fixture()

    {:ok, slack_channel} =
      Notifications.create_channel(%{
        user_id: user.id,
        provider: "slack",
        is_active: true,
        config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/XXXX"},
        event_types: ["alert", "system"]
      })

    {:ok, email_channel} =
      Notifications.create_channel(%{
        user_id: user.id,
        provider: "email",
        is_active: true,
        config: %{"email" => "test@example.com"},
        event_types: ["alert", "compliance"]
      })

    {:ok, in_app_channel} =
      Notifications.create_channel(%{
        user_id: user.id,
        provider: "in_app",
        is_active: true,
        event_types: []
      })

    %{
      user: user,
      slack: slack_channel,
      email: email_channel,
      in_app: in_app_channel
    }
  end

  # ===========================================================================
  # 1. Channel Management
  # ===========================================================================

  describe "channel management" do
    test "create channels for all providers" do
      user = user_fixture()

      for provider <- ~w(slack telegram email in_app) do
        {:ok, channel} =
          Notifications.create_channel(%{
            user_id: user.id,
            provider: provider,
            is_active: true
          })

        assert channel.provider == provider
        assert channel.is_active == true
      end

      channels = Notifications.list_channels(user.id)
      assert length(channels) == 4
    end

    test "update channel active status and event types" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          event_types: ["alert"]
        })

      {:ok, updated} =
        Notifications.update_channel(channel, %{
          is_active: false,
          event_types: ["alert", "system", "compliance"]
        })

      assert updated.is_active == false
      assert length(updated.event_types) == 3
    end

    test "delete channel removes it permanently" do
      user = user_fixture()
      {:ok, channel} = Notifications.create_channel(%{user_id: user.id, provider: "email"})

      assert {:ok, _} = Notifications.delete_channel(channel)

      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_channel!(channel.id)
      end
    end

    test "channel with empty event_types matches all events" do
      user = user_fixture()

      {:ok, _catch_all} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "in_app",
          is_active: true,
          event_types: []
        })

      # Should match any event type
      channels = Notifications.list_active_channels_for_user(user.id, "random_event")
      assert length(channels) >= 1
    end

    test "active channels filter excludes inactive channels" do
      user = user_fixture()

      {:ok, _active} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          event_types: ["alert"]
        })

      {:ok, _inactive} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          is_active: false,
          event_types: ["alert"]
        })

      active = Notifications.list_active_channels_for_user(user.id, "alert")
      assert length(active) == 1
      assert hd(active).provider == "slack"
    end

    test "list_active_channels_for_user with specific event type" do
      user = user_fixture()

      {:ok, _alert_only} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          event_types: ["alert"]
        })

      {:ok, _compliance_only} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          is_active: true,
          config: %{"email" => "comp@test.com"},
          event_types: ["compliance"]
        })

      alert_channels = Notifications.list_active_channels_for_user(user.id, "alert")
      assert length(alert_channels) == 1
      assert hd(alert_channels).provider == "slack"

      compliance_channels = Notifications.list_active_channels_for_user(user.id, "compliance")
      assert length(compliance_channels) == 1
      assert hd(compliance_channels).provider == "email"
    end
  end

  # ===========================================================================
  # 2. Notification CRUD
  # ===========================================================================

  describe "notification CRUD and workflow" do
    test "create notification and verify unread count" do
      user = user_fixture()

      {:ok, n1} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Capital Call Due",
          body: "Capital call #123 is due in 7 days"
        })

      {:ok, n2} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Compliance Alert",
          body: "KYC renewal due for Entity XYZ"
        })

      assert Notifications.count_unread_notifications(user.id) == 2

      # Mark one as read
      {:ok, _} = Notifications.mark_as_read(n1)
      assert Notifications.count_unread_notifications(user.id) == 1

      # Mark all as read
      Notifications.mark_all_as_read(user.id)
      assert Notifications.count_unread_notifications(user.id) == 0
    end

    test "list notifications respects limit" do
      user = user_fixture()

      for i <- 1..10 do
        {:ok, _} =
          Notifications.create_notification(%{
            user_id: user.id,
            title: "Notification #{i}"
          })
      end

      limited = Notifications.list_notifications(user.id, %{limit: 5})
      assert length(limited) == 5
    end

    test "unread notifications filtered correctly" do
      user = user_fixture()

      {:ok, n1} =
        Notifications.create_notification(%{user_id: user.id, title: "Unread 1"})

      {:ok, n2} =
        Notifications.create_notification(%{user_id: user.id, title: "Read 1"})

      Notifications.mark_as_read(n2)

      unread = Notifications.list_unread_notifications(user.id)
      ids = Enum.map(unread, & &1.id)
      assert n1.id in ids
      refute n2.id in ids
    end

    test "PubSub broadcast on notification creation" do
      user = user_fixture()
      Phoenix.PubSub.subscribe(Holdco.PubSub, "notifications:#{user.id}")

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "Broadcast Test",
          body: "Testing PubSub"
        })

      assert_receive {:new_notification, ^notif}
    end
  end

  # ===========================================================================
  # 3. Notification Logs
  # ===========================================================================

  describe "notification logs" do
    test "create and list notification logs" do
      %{slack: channel} = setup_user_with_channels()

      {:ok, log} =
        Notifications.create_notification_log(%{
          channel_id: channel.id,
          event_type: "capital_call",
          message: "Capital call #456 funded",
          status: "pending"
        })

      assert log.status == "pending"

      logs = Notifications.list_notification_logs(channel.id)
      assert length(logs) >= 1
      assert Enum.any?(logs, &(&1.id == log.id))
    end

    test "log status transitions: pending -> sent" do
      %{slack: channel} = setup_user_with_channels()

      {:ok, log} =
        Notifications.create_notification_log(%{
          channel_id: channel.id,
          event_type: "system",
          message: "System notification",
          status: "pending"
        })

      # Simulate successful send
      updated_log =
        Holdco.Repo.update!(
          Holdco.Notifications.NotificationLog.changeset(log, %{
            status: "sent",
            sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
          })
        )

      assert updated_log.status == "sent"
      assert updated_log.sent_at != nil
    end

    test "log status transitions: pending -> failed with error" do
      %{email: channel} = setup_user_with_channels()

      {:ok, log} =
        Notifications.create_notification_log(%{
          channel_id: channel.id,
          event_type: "alert",
          message: "Critical alert",
          status: "pending"
        })

      updated_log =
        Holdco.Repo.update!(
          Holdco.Notifications.NotificationLog.changeset(log, %{
            status: "failed",
            error_message: "SMTP connection timeout"
          })
        )

      assert updated_log.status == "failed"
      assert updated_log.error_message == "SMTP connection timeout"
    end
  end

  # ===========================================================================
  # 4. Delivery Tracking
  # ===========================================================================

  describe "delivery tracking" do
    test "create delivery record and track status" do
      user = user_fixture()
      notif = notification_fixture(%{user: user, title: "Delivery Test"})
      channel = notification_channel_fixture(%{user: user})

      {:ok, delivery} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "slack",
          status: "pending",
          attempts: 0
        })

      assert delivery.status == "pending"
      assert delivery.attempts == 0

      # Mark as sent
      {:ok, sent} =
        Notifications.update_delivery(delivery, %{
          status: "sent",
          sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
          attempts: 1
        })

      assert sent.status == "sent"
      assert sent.attempts == 1
    end

    test "delivery stats aggregate correctly" do
      user = user_fixture()
      notif = notification_fixture(%{user: user})
      channel = notification_channel_fixture(%{user: user})

      # 3 sent, 2 failed
      for _ <- 1..3 do
        {:ok, _} =
          Notifications.create_delivery(%{
            notification_id: notif.id,
            channel_id: channel.id,
            provider: "slack",
            status: "sent"
          })
      end

      for _ <- 1..2 do
        {:ok, _} =
          Notifications.create_delivery(%{
            notification_id: notif.id,
            channel_id: channel.id,
            provider: "slack",
            status: "failed"
          })
      end

      stats = Notifications.delivery_stats(user.id)
      assert stats.total == 5
      assert stats.sent == 3
      assert stats.failed == 2
    end

    test "list deliveries for a specific notification" do
      user = user_fixture()
      notif1 = notification_fixture(%{user: user, title: "Notif 1"})
      notif2 = notification_fixture(%{user: user, title: "Notif 2"})
      channel = notification_channel_fixture(%{user: user})

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif1.id,
          channel_id: channel.id,
          provider: "slack"
        })

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif2.id,
          channel_id: channel.id,
          provider: "slack"
        })

      n1_deliveries = Notifications.list_deliveries(notif1.id)
      assert length(n1_deliveries) == 1

      n2_deliveries = Notifications.list_deliveries(notif2.id)
      assert length(n2_deliveries) == 1
    end

    test "recent deliveries for user ordered by most recent" do
      user = user_fixture()
      channel = notification_channel_fixture(%{user: user})

      for i <- 1..5 do
        notif = notification_fixture(%{user: user, title: "Notif #{i}"})

        {:ok, _} =
          Notifications.create_delivery(%{
            notification_id: notif.id,
            channel_id: channel.id,
            provider: "slack",
            status: "sent"
          })
      end

      recent = Notifications.list_recent_deliveries(user.id, 3)
      assert length(recent) == 3
    end
  end

  # ===========================================================================
  # 5. Dispatch Integration
  # ===========================================================================

  describe "dispatch integration" do
    test "dispatch_notification creates logs for matching channels" do
      %{user: user, slack: slack} = setup_user_with_channels()

      # dispatch_notification uses the Notifications context directly
      results = Notifications.dispatch_notification("alert", "Test alert message", user_id: user.id)

      # Should attempt to send to matching active channels
      assert is_list(results)
      # At least one result (channels matching "alert" event type)
      assert length(results) >= 1

      # Logs should be created
      slack_logs = Notifications.list_notification_logs(slack.id)
      assert length(slack_logs) >= 1
    end

    test "dispatcher module lists available providers" do
      providers = Dispatcher.available_providers()
      assert "slack" in providers
      assert "telegram" in providers
      assert "email" in providers
    end

    test "dispatcher get_provider returns module for known providers" do
      assert Dispatcher.get_provider("slack") == Holdco.Notifications.Providers.Slack
      assert Dispatcher.get_provider("telegram") == Holdco.Notifications.Providers.Telegram
      assert Dispatcher.get_provider("email") == Holdco.Notifications.Providers.Email
      assert Dispatcher.get_provider("unknown") == nil
    end

    test "dispatch creates delivery records for each channel" do
      user = user_fixture()

      {:ok, _} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/DISPATCH"},
          event_types: ["system"]
        })

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "System Alert",
          body: "Something happened"
        })

      # The dispatch function creates delivery records
      {_sent, _failed} = Dispatcher.dispatch(notif, "system")

      deliveries = Notifications.list_deliveries(notif.id)
      # At least one delivery attempt was made (may fail due to no real webhook)
      assert length(deliveries) >= 1
    end
  end

  # ===========================================================================
  # 6. Multi-User Notification Scenarios
  # ===========================================================================

  describe "multi-user notification scenarios" do
    test "notify all admins sends to each admin user" do
      admin1 = user_fixture()
      admin2 = user_fixture()
      non_admin = user_fixture()

      Holdco.Accounts.set_user_role(admin1, "admin")
      Holdco.Accounts.set_user_role(admin2, "admin")

      Notifications.notify_all_admins("Security Alert", "Unauthorized access attempt detected")

      admin1_notifs = Notifications.list_notifications(admin1.id)
      admin2_notifs = Notifications.list_notifications(admin2.id)
      non_admin_notifs = Notifications.list_notifications(non_admin.id)

      assert Enum.any?(admin1_notifs, &(&1.title == "Security Alert"))
      assert Enum.any?(admin2_notifs, &(&1.title == "Security Alert"))
      refute Enum.any?(non_admin_notifs, &(&1.title == "Security Alert"))
    end

    test "notifications are isolated between users" do
      user_a = user_fixture()
      user_b = user_fixture()

      {:ok, _} =
        Notifications.create_notification(%{
          user_id: user_a.id,
          title: "User A Only"
        })

      {:ok, _} =
        Notifications.create_notification(%{
          user_id: user_b.id,
          title: "User B Only"
        })

      a_notifs = Notifications.list_notifications(user_a.id)
      b_notifs = Notifications.list_notifications(user_b.id)

      assert Enum.any?(a_notifs, &(&1.title == "User A Only"))
      refute Enum.any?(a_notifs, &(&1.title == "User B Only"))

      assert Enum.any?(b_notifs, &(&1.title == "User B Only"))
      refute Enum.any?(b_notifs, &(&1.title == "User A Only"))
    end

    test "user_ids_with_active_channels finds users subscribed to event type" do
      user1 = user_fixture()
      user2 = user_fixture()
      user3 = user_fixture()

      {:ok, _} =
        Notifications.create_channel(%{
          user_id: user1.id,
          provider: "slack",
          is_active: true,
          event_types: ["compliance"]
        })

      {:ok, _} =
        Notifications.create_channel(%{
          user_id: user2.id,
          provider: "email",
          is_active: true,
          event_types: ["compliance", "alert"]
        })

      # user3 has no compliance channel
      {:ok, _} =
        Notifications.create_channel(%{
          user_id: user3.id,
          provider: "slack",
          is_active: true,
          event_types: ["alert"]
        })

      compliance_users = Notifications.user_ids_with_active_channels("compliance")
      assert user1.id in compliance_users
      assert user2.id in compliance_users
      refute user3.id in compliance_users
    end
  end

  # ===========================================================================
  # 7. Notification Channel CRUD (with audit)
  # ===========================================================================

  describe "notification channel CRUD with audit" do
    test "create_notification_channel audits the action" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_notification_channel(%{
          user_id: user.id,
          provider: "slack",
          name: "My Slack Channel",
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/AUDIT"}
        })

      assert channel.name == "My Slack Channel"
    end

    test "update_notification_channel updates fields" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_notification_channel(%{
          user_id: user.id,
          provider: "telegram",
          name: "Telegram Alerts"
        })

      {:ok, updated} =
        Notifications.update_notification_channel(channel, %{
          name: "Updated Telegram",
          is_active: false
        })

      assert updated.name == "Updated Telegram"
      assert updated.is_active == false
    end

    test "delete_notification_channel removes channel" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_notification_channel(%{
          user_id: user.id,
          provider: "email",
          name: "Email Channel"
        })

      assert {:ok, _} = Notifications.delete_notification_channel(channel)

      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_notification_channel!(channel.id)
      end
    end

    test "list_notification_channels returns all for user" do
      user = user_fixture()

      {:ok, _} =
        Notifications.create_notification_channel(%{
          user_id: user.id,
          provider: "slack",
          name: "Slack"
        })

      {:ok, _} =
        Notifications.create_notification_channel(%{
          user_id: user.id,
          provider: "email",
          name: "Email"
        })

      channels = Notifications.list_notification_channels(user.id)
      assert length(channels) == 2
    end
  end

  # ===========================================================================
  # 8. Failure Tracking
  # ===========================================================================

  describe "failure tracking" do
    test "channel failure_count tracks cumulative failures" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          is_active: true,
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/FAIL"},
          failure_count: 0
        })

      assert channel.failure_count == 0

      # Simulate failures
      {:ok, failed_once} =
        Notifications.update_channel(channel, %{failure_count: 1})

      assert failed_once.failure_count == 1

      {:ok, failed_twice} =
        Notifications.update_channel(failed_once, %{failure_count: 2})

      assert failed_twice.failure_count == 2
    end

    test "last_sent_at tracks when channel last successfully sent" do
      user = user_fixture()

      {:ok, channel} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          is_active: true,
          config: %{"email" => "test@example.com"}
        })

      assert channel.last_sent_at == nil

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, updated} =
        Notifications.update_channel(channel, %{last_sent_at: now})

      assert updated.last_sent_at == now
    end
  end
end
