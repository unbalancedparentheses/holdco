defmodule Holdco.Notifications.NotificationChannelTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures
  import Holdco.AccountsFixtures

  alias Holdco.Notifications

  describe "notification_channels CRUD" do
    test "list_notification_channels/1 returns channels for user" do
      channel = notification_channel_fixture()
      results = Notifications.list_notification_channels(channel.user_id)
      assert Enum.any?(results, &(&1.id == channel.id))
    end

    test "list_notification_channels/1 does not return other users channels" do
      channel = notification_channel_fixture()
      other_user = user_fixture()
      results = Notifications.list_notification_channels(other_user.id)
      refute Enum.any?(results, &(&1.id == channel.id))
    end

    test "get_notification_channel!/1 returns the channel" do
      channel = notification_channel_fixture()
      fetched = Notifications.get_notification_channel!(channel.id)
      assert fetched.id == channel.id
    end

    test "get_notification_channel!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_notification_channel!(0)
      end
    end

    test "create_notification_channel/1 with valid data" do
      user = user_fixture()

      assert {:ok, channel} =
               Notifications.create_notification_channel(%{
                 user_id: user.id,
                 name: "My Slack Channel",
                 provider: "slack",
                 is_active: true,
                 config: %{"webhook_url" => "https://hooks.slack.com/test"}
               })

      assert channel.name == "My Slack Channel"
      assert channel.provider == "slack"
      assert channel.is_active == true
    end

    test "create_notification_channel/1 with telegram provider" do
      user = user_fixture()

      assert {:ok, channel} =
               Notifications.create_notification_channel(%{
                 user_id: user.id,
                 name: "Telegram Alerts",
                 provider: "telegram",
                 config: %{"bot_token" => "123:ABC", "chat_id" => "456"}
               })

      assert channel.provider == "telegram"
    end

    test "create_notification_channel/1 with email provider" do
      user = user_fixture()

      assert {:ok, channel} =
               Notifications.create_notification_channel(%{
                 user_id: user.id,
                 name: "Email Notifications",
                 provider: "email",
                 config: %{"email" => "test@example.com"}
               })

      assert channel.provider == "email"
    end

    test "create_notification_channel/1 fails without required fields" do
      assert {:error, changeset} = Notifications.create_notification_channel(%{})
      errors = errors_on(changeset)
      assert errors[:user_id]
      assert errors[:provider]
    end

    test "create_notification_channel/1 fails with invalid provider" do
      user = user_fixture()

      assert {:error, changeset} =
               Notifications.create_notification_channel(%{
                 user_id: user.id,
                 provider: "invalid"
               })

      assert errors_on(changeset)[:provider]
    end

    test "update_notification_channel/2 with valid data" do
      channel = notification_channel_fixture()

      assert {:ok, updated} =
               Notifications.update_notification_channel(channel, %{
                 name: "Updated Name",
                 is_active: false
               })

      assert updated.name == "Updated Name"
      assert updated.is_active == false
    end

    test "delete_notification_channel/1 removes the channel" do
      channel = notification_channel_fixture()
      assert {:ok, _} = Notifications.delete_notification_channel(channel)

      assert_raise Ecto.NoResultsError, fn ->
        Notifications.get_notification_channel!(channel.id)
      end
    end
  end

  describe "notification_logs" do
    test "list_notification_logs/1 returns logs for channel" do
      log = notification_log_fixture()
      results = Notifications.list_notification_logs(log.channel_id)
      assert Enum.any?(results, &(&1.id == log.id))
    end

    test "create_notification_log/1 with valid data" do
      channel = notification_channel_fixture()

      assert {:ok, log} =
               Notifications.create_notification_log(%{
                 channel_id: channel.id,
                 event_type: "alert",
                 message: "Test alert message",
                 status: "sent"
               })

      assert log.event_type == "alert"
      assert log.status == "sent"
    end

    test "create_notification_log/1 fails without required fields" do
      assert {:error, changeset} = Notifications.create_notification_log(%{})
      errors = errors_on(changeset)
      assert errors[:channel_id]
      assert errors[:event_type]
      assert errors[:message]
    end
  end

  describe "providers" do
    test "Slack validate_config checks webhook_url" do
      assert :ok = Holdco.Notifications.Providers.Slack.validate_config(%{"webhook_url" => "https://hooks.slack.com/test"})
      assert {:error, _} = Holdco.Notifications.Providers.Slack.validate_config(%{})
      assert {:error, _} = Holdco.Notifications.Providers.Slack.validate_config(%{"webhook_url" => "http://example.com"})
    end

    test "Telegram validate_config checks bot_token and chat_id" do
      assert :ok = Holdco.Notifications.Providers.Telegram.validate_config(%{"bot_token" => "123:ABC", "chat_id" => "456"})
      assert {:error, _} = Holdco.Notifications.Providers.Telegram.validate_config(%{})
      assert {:error, _} = Holdco.Notifications.Providers.Telegram.validate_config(%{"bot_token" => "123:ABC"})
    end

    test "Email validate_config checks email field" do
      assert :ok = Holdco.Notifications.Providers.Email.validate_config(%{"email" => "test@example.com"})
      assert {:error, _} = Holdco.Notifications.Providers.Email.validate_config(%{})
      assert {:error, _} = Holdco.Notifications.Providers.Email.validate_config(%{"email" => ""})
    end

    test "Slack provider_name returns slack" do
      assert "slack" == Holdco.Notifications.Providers.Slack.provider_name()
    end

    test "Telegram provider_name returns telegram" do
      assert "telegram" == Holdco.Notifications.Providers.Telegram.provider_name()
    end

    test "Email provider_name returns email" do
      assert "email" == Holdco.Notifications.Providers.Email.provider_name()
    end
  end

  describe "dispatcher" do
    test "get_provider returns correct module for known providers" do
      assert Holdco.Notifications.Dispatcher.get_provider("slack") == Holdco.Notifications.Providers.Slack
      assert Holdco.Notifications.Dispatcher.get_provider("telegram") == Holdco.Notifications.Providers.Telegram
      assert Holdco.Notifications.Dispatcher.get_provider("email") == Holdco.Notifications.Providers.Email
    end

    test "get_provider returns nil for unknown provider" do
      assert Holdco.Notifications.Dispatcher.get_provider("unknown") == nil
    end

    test "available_providers returns list of providers" do
      providers = Holdco.Notifications.Dispatcher.available_providers()
      assert "slack" in providers
      assert "telegram" in providers
      assert "email" in providers
    end
  end
end
