defmodule HoldcoWeb.NotificationSettingsLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "can switch to deliveries tab", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/settings/notifications")
      html = render_click(live, "switch_tab", %{"tab" => "deliveries"})
      assert html =~ "Recent Deliveries"
      assert html =~ "No delivery history yet."
    end
  end

  describe "switch_tab event" do
    test "switching to channels tab shows channels content", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      # Switch to deliveries first
      render_click(view, "switch_tab", %{"tab" => "deliveries"})

      # Switch back to channels
      html = render_click(view, "switch_tab", %{"tab" => "channels"})
      assert html =~ "Notification Channels"
    end

    test "switching to deliveries tab shows delivery history", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      html = render_click(view, "switch_tab", %{"tab" => "deliveries"})
      assert html =~ "Recent Deliveries"
    end
  end

  describe "show_form and close_form events" do
    test "show_form opens the add channel dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      html = render_click(view, "show_form", %{})
      assert html =~ "Add Channel"
      assert html =~ "dialog-overlay"
      assert html =~ "Provider"
    end

    test "close_form closes the dialog", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      html = render_click(view, "close_form", %{})
      refute html =~ "dialog-overlay"
    end
  end

  describe "select_provider event" do
    test "selecting slack provider shows webhook URL field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})

      html = render_click(view, "select_provider", %{"provider" => "slack"})
      assert html =~ "Webhook URL"
    end

    test "selecting telegram provider shows bot token and chat ID fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})

      html = render_click(view, "select_provider", %{"provider" => "telegram"})
      assert html =~ "Bot Token"
      assert html =~ "Chat ID"
    end

    test "selecting email provider shows email address field", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})

      html = render_click(view, "select_provider", %{"provider" => "email"})
      assert html =~ "Email Address"
    end
  end

  describe "save_channel event" do
    test "creating a slack channel shows success flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      render_click(view, "select_provider", %{"provider" => "slack"})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "slack",
            "webhook_url" => "https://hooks.slack.com/services/T00/B00/test",
            "notes" => "Test channel"
          }
        })
        |> render_submit()

      assert html =~ "Channel created successfully"
    end

    test "creating an email channel shows success flash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      render_click(view, "select_provider", %{"provider" => "email"})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "email",
            "email" => "test@example.com",
            "notes" => "Email notifications"
          }
        })
        |> render_submit()

      assert html =~ "Channel created successfully"
    end

    test "creating a channel with missing provider shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "",
            "notes" => ""
          }
        })
        |> render_submit()

      assert html =~ "Failed to save channel"
    end
  end

  describe "edit_channel event" do
    test "editing a channel opens the form pre-populated", %{conn: conn, user: user} do
      channel = notification_channel_fixture(%{user: user, provider: "slack"})

      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      html = render_click(view, "edit_channel", %{"id" => to_string(channel.id)})
      assert html =~ "Edit Channel"
      assert html =~ "dialog-overlay"
    end

    test "updating an existing channel shows success flash", %{conn: conn, user: user} do
      channel = notification_channel_fixture(%{user: user, provider: "slack"})

      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      render_click(view, "edit_channel", %{"id" => to_string(channel.id)})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "slack",
            "webhook_url" => "https://hooks.slack.com/services/T00/B00/updated",
            "notes" => "Updated channel"
          }
        })
        |> render_submit()

      assert html =~ "Channel updated successfully"
    end
  end

  describe "delete_channel event" do
    test "deleting a channel removes it and shows success flash", %{conn: conn, user: user} do
      notification_channel_fixture(%{user: user, provider: "slack"})

      {:ok, view, html} = live(conn, ~p"/settings/notifications")
      assert html =~ "Slack"

      html = render_click(view, "delete_channel", %{"id" => to_string(Holdco.Notifications.list_channels(user.id) |> hd() |> Map.get(:id))})
      assert html =~ "Channel deleted"
    end
  end

  describe "toggle_channel event" do
    test "toggling a channel changes its active status", %{conn: conn, user: user} do
      channel = notification_channel_fixture(%{user: user, provider: "slack", is_active: true})

      {:ok, view, html} = live(conn, ~p"/settings/notifications")
      assert html =~ "Active"

      html = render_click(view, "toggle_channel", %{"id" => to_string(channel.id)})
      assert html =~ "Inactive"
    end

    test "toggling an inactive channel activates it", %{conn: conn, user: user} do
      channel = notification_channel_fixture(%{user: user, provider: "slack", is_active: false})

      {:ok, view, html} = live(conn, ~p"/settings/notifications")
      assert html =~ "Inactive"

      html = render_click(view, "toggle_channel", %{"id" => to_string(channel.id)})
      assert html =~ "Active"
    end
  end

  describe "channel display" do
    test "shows channel details in the table", %{conn: conn, user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "slack",
        is_active: true,
        event_types: ["alert", "system"],
        notes: "My Slack Channel"
      })

      {:ok, _view, html} = live(conn, ~p"/settings/notifications")

      assert html =~ "Slack"
      assert html =~ "Active"
      assert html =~ "alert"
      assert html =~ "system"
      assert html =~ "My Slack Channel"
    end

    test "shows all events when event_types is empty", %{conn: conn, user: user} do
      notification_channel_fixture(%{
        user: user,
        provider: "email",
        config: %{"email" => "test@example.com"},
        event_types: []
      })

      {:ok, _view, html} = live(conn, ~p"/settings/notifications")
      assert html =~ "All events"
    end
  end

  # ------------------------------------------------------------------
  # Delivery history display
  # ------------------------------------------------------------------

  describe "delivery history display" do
    test "shows delivery details in history tab", %{conn: conn, user: user} do
      notification = notification_fixture(%{user: user, title: "Test Alert", body: "Something happened"})
      channel = notification_channel_fixture(%{user: user, provider: "slack"})

      notification_delivery_fixture(%{
        user: user,
        notification: notification,
        channel: channel,
        provider: "slack",
        status: "sent"
      })

      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      html = render_click(view, "switch_tab", %{"tab" => "deliveries"})

      assert html =~ "Recent Deliveries"
      assert html =~ "Slack"
      assert html =~ "sent"
    end

    test "shows empty delivery history state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      html = render_click(view, "switch_tab", %{"tab" => "deliveries"})
      assert html =~ "No delivery history yet."
    end
  end

  # ------------------------------------------------------------------
  # Telegram channel creation
  # ------------------------------------------------------------------

  describe "telegram channel" do
    test "creating a telegram channel shows success", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      render_click(view, "select_provider", %{"provider" => "telegram"})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "telegram",
            "bot_token" => "123456:ABC-DEF-test",
            "chat_id" => "-1001234567890",
            "notes" => "Telegram alerts"
          }
        })
        |> render_submit()

      assert html =~ "Channel created successfully"
    end
  end

  # ------------------------------------------------------------------
  # In-app channel creation
  # ------------------------------------------------------------------

  describe "in_app channel" do
    test "creating an in_app channel shows success", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      render_click(view, "select_provider", %{"provider" => "in_app"})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "in_app",
            "notes" => "In-app notifications"
          }
        })
        |> render_submit()

      assert html =~ "Channel created successfully"
    end
  end

  # ------------------------------------------------------------------
  # Event type checkboxes
  # ------------------------------------------------------------------

  describe "event type subscriptions" do
    test "creating channel with specific event types saves them", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      render_click(view, "show_form", %{})
      render_click(view, "select_provider", %{"provider" => "slack"})

      html =
        view
        |> form("form[phx-submit=\"save_channel\"]", %{
          "channel" => %{
            "provider" => "slack",
            "webhook_url" => "https://hooks.slack.com/services/T00/B00/events",
            "notes" => "Alert-only channel"
          },
          "event_types" => ["alert", "approval"]
        })
        |> render_submit()

      assert html =~ "Channel created successfully"
      assert html =~ "alert"
      assert html =~ "approval"
    end
  end

  # ------------------------------------------------------------------
  # handle_info pubsub
  # ------------------------------------------------------------------

  describe "handle_info" do
    test "new_notification message reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      send(view.pid, {:new_notification, %{}})
      html = render(view)
      assert html =~ "Notification Settings"
    end

    test "unknown message does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings/notifications")

      send(view.pid, :some_unknown_message)
      html = render(view)
      assert html =~ "Notification Settings"
    end
  end

  # ------------------------------------------------------------------
  # Stats bar values
  # ------------------------------------------------------------------

  describe "stats bar with data" do
    test "shows correct stats for channels and deliveries", %{conn: conn, user: user} do
      notification_channel_fixture(%{user: user, provider: "slack"})
      notification_channel_fixture(%{user: user, provider: "email", config: %{"email" => "stats@test.com"}})

      {:ok, _view, html} = live(conn, ~p"/settings/notifications")

      assert html =~ "<strong>2</strong> channels configured"
    end
  end

  describe "edit channel form shows existing data" do
    test "editing a channel pre-selects provider and shows fields", %{conn: conn, user: user} do
      channel = notification_channel_fixture(%{
        user: user,
        provider: "telegram",
        config: %{"bot_token" => "tok123", "chat_id" => "-999"}
      })

      {:ok, view, _html} = live(conn, ~p"/settings/notifications")
      html = render_click(view, "edit_channel", %{"id" => to_string(channel.id)})

      assert html =~ "Edit Channel"
      assert html =~ "Bot Token"
      assert html =~ "Chat ID"
      assert html =~ "tok123"
      assert html =~ "-999"
    end
  end
end
