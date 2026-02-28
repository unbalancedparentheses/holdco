defmodule Holdco.NotificationsTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Notifications

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
end
