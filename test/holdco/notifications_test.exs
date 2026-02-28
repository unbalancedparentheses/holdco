defmodule Holdco.NotificationsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Notifications
  alias Holdco.Notifications.{NotificationChannel, NotificationDelivery}

  describe "notifications" do
    test "create_notification/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      {:ok, n} = Notifications.create_notification(%{user_id: user.id, title: "Test"})
      assert n.title == "Test"
    end

    test "list_notifications/2" do
      user = Holdco.AccountsFixtures.user_fixture()
      notification_fixture(%{user: user})
      assert length(Notifications.list_notifications(user.id, %{})) > 0
    end

    test "unread_count/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      notification_fixture(%{user: user})
      assert Notifications.unread_count(user.id) >= 1
    end

    test "mark_read/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      n = notification_fixture(%{user: user})
      {:ok, marked} = Notifications.mark_read(n.id)
      assert marked.read_at != nil
    end

    test "mark_all_read/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      notification_fixture(%{user: user})
      notification_fixture(%{user: user, title: "Second"})
      {count, _} = Notifications.mark_all_read(user.id)
      assert count >= 2
    end

    test "delete_notification/1" do
      user = Holdco.AccountsFixtures.user_fixture()
      n = notification_fixture(%{user: user})
      {:ok, _} = Notifications.delete_notification(n)
    end

    test "list_notifications/2 respects limit option" do
      user = Holdco.AccountsFixtures.user_fixture()

      for i <- 1..5 do
        notification_fixture(%{user: user, title: "Notif #{i}"})
      end

      notifs = Notifications.list_notifications(user.id, %{limit: 3})
      assert length(notifs) == 3
    end

    test "list_notifications/2 returns all matching notifications" do
      user = Holdco.AccountsFixtures.user_fixture()
      n1 = notification_fixture(%{user: user, title: "First"})
      n2 = notification_fixture(%{user: user, title: "Second"})

      notifs = Notifications.list_notifications(user.id, %{})
      ids = Enum.map(notifs, & &1.id)
      assert n1.id in ids
      assert n2.id in ids
    end

    test "list_notifications/2 returns empty for user with no notifications" do
      user = Holdco.AccountsFixtures.user_fixture()
      assert Notifications.list_notifications(user.id, %{}) == []
    end

    test "unread_count/1 returns 0 after all are read" do
      user = Holdco.AccountsFixtures.user_fixture()
      notification_fixture(%{user: user})
      notification_fixture(%{user: user})

      Notifications.mark_all_read(user.id)
      assert Notifications.unread_count(user.id) == 0
    end

    test "mark_read/1 sets read_at timestamp" do
      user = Holdco.AccountsFixtures.user_fixture()
      n = notification_fixture(%{user: user})

      assert n.read_at == nil

      {:ok, marked} = Notifications.mark_read(n.id)
      assert marked.read_at != nil
      assert %DateTime{} = marked.read_at
    end

    test "create_notification/1 broadcasts via PubSub" do
      user = Holdco.AccountsFixtures.user_fixture()

      Phoenix.PubSub.subscribe(Holdco.PubSub, "notifications:#{user.id}")

      {:ok, notif} =
        Notifications.create_notification(%{
          user_id: user.id,
          title: "PubSub Test",
          body: "Testing broadcast"
        })

      assert_receive {:new_notification, ^notif}
    end

    test "notify_all_admins/3 sends notifications to all admin users" do
      user1 = Holdco.AccountsFixtures.user_fixture()
      user2 = Holdco.AccountsFixtures.user_fixture()
      Holdco.Accounts.set_user_role(user1, "admin")
      Holdco.Accounts.set_user_role(user2, "admin")

      Notifications.notify_all_admins("Alert", "Something happened", type: "info")

      notifs1 = Notifications.list_notifications(user1.id, %{})
      notifs2 = Notifications.list_notifications(user2.id, %{})

      assert Enum.any?(notifs1, &(&1.title == "Alert"))
      assert Enum.any?(notifs2, &(&1.title == "Alert"))
    end

    test "notify_all_admins/3 does nothing when no admins exist" do
      # Just a non-admin user
      _user = Holdco.AccountsFixtures.user_fixture()

      result = Notifications.notify_all_admins("Alert", "No admins")
      assert result == []
    end

    test "create_notification/1 with missing required fields" do
      {:error, changeset} = Notifications.create_notification(%{})
      assert changeset.valid? == false
    end
  end

  # ── Channels ─────────────────────────────────────────────

  describe "channels" do
    test "create_channel/1 with valid attrs" do
      user = user_fixture()

      assert {:ok, %NotificationChannel{} = channel} =
               Notifications.create_channel(%{
                 user_id: user.id,
                 provider: "slack",
                 config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/XXX"},
                 event_types: ["alert", "system"]
               })

      assert channel.provider == "slack"
      assert channel.is_active == true
      assert channel.event_types == ["alert", "system"]
    end

    test "create_channel/1 validates provider inclusion" do
      user = user_fixture()

      assert {:error, changeset} =
               Notifications.create_channel(%{
                 user_id: user.id,
                 provider: "invalid_provider"
               })

      assert %{provider: ["is invalid"]} = errors_on(changeset)
    end

    test "create_channel/1 requires user_id and provider" do
      assert {:error, changeset} = Notifications.create_channel(%{})
      errors = errors_on(changeset)
      assert errors[:user_id]
      assert errors[:provider]
    end

    test "create_channel/1 accepts all valid providers" do
      user = user_fixture()

      for provider <- ~w(slack telegram email in_app) do
        assert {:ok, %NotificationChannel{}} =
                 Notifications.create_channel(%{
                   user_id: user.id,
                   provider: provider
                 })
      end
    end

    test "update_channel/2 updates a channel" do
      user = user_fixture()
      channel = notification_channel_fixture(%{user: user})

      {:ok, updated} =
        Notifications.update_channel(channel, %{
          is_active: false,
          event_types: ["task"]
        })

      assert updated.is_active == false
      assert updated.event_types == ["task"]
    end

    test "delete_channel/1 deletes a channel" do
      user = user_fixture()
      channel = notification_channel_fixture(%{user: user})
      assert {:ok, _} = Notifications.delete_channel(channel)

      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_channel!(channel.id)
      end
    end

    test "list_channels/1 lists channels for a user" do
      user = user_fixture()
      notification_channel_fixture(%{user: user, provider: "slack"})
      notification_channel_fixture(%{user: user, provider: "email", config: %{"email" => "test@example.com"}})
      other_user = user_fixture()
      notification_channel_fixture(%{user: other_user})

      channels = Notifications.list_channels(user.id)
      assert length(channels) == 2
      assert Enum.all?(channels, &(&1.user_id == user.id))
    end

    test "list_active_channels_for_user/2 returns only active channels" do
      user = user_fixture()
      notification_channel_fixture(%{user: user, is_active: true, provider: "slack"})

      {:ok, inactive} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          is_active: false,
          config: %{"email" => "test@example.com"}
        })

      channels = Notifications.list_active_channels_for_user(user.id)
      assert length(channels) == 1
      refute Enum.any?(channels, &(&1.id == inactive.id))
    end

    test "list_active_channels_for_user/2 filters by event_type" do
      user = user_fixture()
      notification_channel_fixture(%{user: user, event_types: ["alert", "system"]})

      {:ok, _task_only} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "email",
          config: %{"email" => "test@example.com"},
          event_types: ["task"]
        })

      alert_channels = Notifications.list_active_channels_for_user(user.id, "alert")
      assert length(alert_channels) == 1

      task_channels = Notifications.list_active_channels_for_user(user.id, "task")
      assert length(task_channels) == 1
    end

    test "channels with empty event_types match all events" do
      user = user_fixture()

      {:ok, _all_events} =
        Notifications.create_channel(%{
          user_id: user.id,
          provider: "slack",
          config: %{"webhook_url" => "https://hooks.slack.com/services/T00/B00/ALL"},
          event_types: []
        })

      channels = Notifications.list_active_channels_for_user(user.id, "any_event")
      assert length(channels) == 1
    end
  end

  # ── Deliveries ───────────────────────────────────────────

  describe "deliveries" do
    test "create_delivery/1 creates a delivery record" do
      user = user_fixture()
      notif = notification_fixture(%{user: user})
      channel = notification_channel_fixture(%{user: user})

      assert {:ok, %NotificationDelivery{} = delivery} =
               Notifications.create_delivery(%{
                 notification_id: notif.id,
                 channel_id: channel.id,
                 provider: "slack",
                 status: "pending"
               })

      assert delivery.status == "pending"
      assert delivery.provider == "slack"
      assert delivery.attempts == 0
    end

    test "update_delivery/2 updates delivery status" do
      user = user_fixture()
      delivery = notification_delivery_fixture(%{user: user})

      {:ok, updated} =
        Notifications.update_delivery(delivery, %{
          status: "sent",
          sent_at: DateTime.utc_now() |> DateTime.truncate(:second),
          attempts: 1
        })

      assert updated.status == "sent"
      assert updated.sent_at != nil
      assert updated.attempts == 1
    end

    test "delivery_stats/1 counts delivery statistics" do
      user = user_fixture()
      notif = notification_fixture(%{user: user})
      channel = notification_channel_fixture(%{user: user})

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "slack",
          status: "sent"
        })

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "slack",
          status: "failed"
        })

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "slack",
          status: "sent"
        })

      stats = Notifications.delivery_stats(user.id)
      assert stats.total == 3
      assert stats.sent == 2
      assert stats.failed == 1
    end

    test "delivery_stats/1 returns zeros for user with no deliveries" do
      user = user_fixture()
      stats = Notifications.delivery_stats(user.id)
      assert stats == %{total: 0, sent: 0, failed: 0}
    end

    test "list_deliveries/1 lists deliveries for a notification" do
      user = user_fixture()
      notif = notification_fixture(%{user: user})
      channel = notification_channel_fixture(%{user: user})

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "slack"
        })

      {:ok, _} =
        Notifications.create_delivery(%{
          notification_id: notif.id,
          channel_id: channel.id,
          provider: "email"
        })

      deliveries = Notifications.list_deliveries(notif.id)
      assert length(deliveries) == 2
    end
  end
end
