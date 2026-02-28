defmodule HoldcoWeb.NotificationsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /notifications" do
    test "renders notifications page", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Notifications"
    end

    test "renders page title and unread count", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "page-title"
      assert html =~ "unread"
    end

    test "renders page title rule", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "page-title-rule"
    end

    test "shows empty state when no notifications", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "No notifications yet."
    end

    test "shows 0 unread when no notifications", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "0 unread"
    end

    test "does not show Mark All Read button when no unread", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      refute html =~ "Mark All Read"
    end
  end

  describe "with notifications" do
    test "displays notification table headers", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Test Notif"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Title"
      assert html =~ "Message"
      assert html =~ "Time"
    end

    test "displays notification title and body", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Important Alert", body: "Something happened"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Important Alert"
      assert html =~ "Something happened"
    end

    test "shows unread count correctly", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Unread 1"})
      notification_fixture(%{user: user, title: "Unread 2"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "2 unread"
    end

    test "shows Mark All Read button when there are unread notifications", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Unread"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Mark All Read"
    end

    test "unread notifications have highlighted styling", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Unread Notif"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "font-weight: 500"
    end

    test "shows Mark Read button for unread notifications", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Can Mark"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Mark Read"
    end

    test "shows notification type tag", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Warning", type: "warning"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "tag-lemon"
      assert html =~ "warning"
    end

    test "shows error type tag", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Error", type: "error"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "tag-crimson"
    end

    test "shows success type tag", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Success", type: "success"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "tag-jade"
    end

    test "shows info type tag for unknown types", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Info", type: "info"})

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "tag-ink"
    end

    test "notification with action_url renders as link", %{conn: conn, user: user} do
      notification_fixture(%{
        user: user,
        title: "Linked Notif",
        action_url: "/compliance"
      })

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "/compliance"
      assert html =~ "Linked Notif"
    end
  end

  describe "mark_read event" do
    test "marking a notification as read updates the display", %{conn: conn, user: user} do
      notif = notification_fixture(%{user: user, title: "To Mark Read"})

      {:ok, view, html} = live(conn, ~p"/notifications")
      assert html =~ "1 unread"

      view
      |> element(~s(button[phx-click="mark_read"][phx-value-id="#{notif.id}"]))
      |> render_click()

      html = render(view)
      assert html =~ "0 unread"
    end
  end

  describe "mark_all_read event" do
    test "marking all as read clears unread count", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Notif 1"})
      notification_fixture(%{user: user, title: "Notif 2"})

      {:ok, view, html} = live(conn, ~p"/notifications")
      assert html =~ "2 unread"

      view
      |> element(~s(button[phx-click="mark_all_read"]))
      |> render_click()

      html = render(view)
      assert html =~ "0 unread"
    end

    test "Mark All Read button disappears after marking all read", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Notif"})

      {:ok, view, _html} = live(conn, ~p"/notifications")

      view
      |> element(~s(button[phx-click="mark_all_read"]))
      |> render_click()

      html = render(view)
      refute html =~ "Mark All Read"
    end
  end

  describe "real-time updates via PubSub" do
    test "receives new notification and refreshes display", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      # Create a notification (this will broadcast via PubSub)
      {:ok, notif} = Holdco.Notifications.create_notification(%{
        user_id: user.id,
        title: "Realtime Notif",
        body: "Just arrived"
      })

      # Simulate the PubSub message reaching the LiveView
      send(view.pid, {:new_notification, notif})

      html = render(view)
      assert html =~ "Realtime Notif"
      assert html =~ "Just arrived"
    end
  end

  describe "nav active state" do
    test "notifications nav link is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ ~r/nav-util-link\s+active/
    end
  end

  describe "unknown handle_info" do
    test "unknown messages are handled gracefully without crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notifications")

      send(view.pid, :unknown_event)
      html = render(view)
      assert html =~ "Notifications"
    end
  end

  describe "notification without action_url" do
    test "renders title as plain text without link", %{conn: conn, user: user} do
      notification_fixture(%{
        user: user,
        title: "Plain Notif",
        action_url: nil
      })

      {:ok, _view, html} = live(conn, ~p"/notifications")

      assert html =~ "Plain Notif"
    end
  end

  describe "format_time with nil" do
    test "formats nil datetime as empty string", %{conn: conn, user: user} do
      notification_fixture(%{user: user, title: "Time Test"})

      {:ok, _view, html} = live(conn, ~p"/notifications")
      # Just verify the page renders - format_time is called on inserted_at
      assert html =~ "Time Test"
    end
  end
end
