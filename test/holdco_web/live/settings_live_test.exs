defmodule HoldcoWeb.SettingsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "GET /settings" do
    test "renders settings page with title, deck, tabs, and tab-body", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "Settings"
      assert html =~ "page-title"
      assert html =~ "Application settings, categories, API keys, webhooks, and backup configuration"
      assert html =~ "page-title-rule"
      assert html =~ ~s(class="tabs")
      assert html =~ ~s(phx-value-tab="settings")
      assert html =~ ~s(phx-value-tab="categories")
      assert html =~ ~s(phx-value-tab="webhooks")
      assert html =~ ~s(phx-value-tab="backups")
      assert html =~ "tab-body"
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="settings"/s
      assert html =~ "Application Settings"
      assert html =~ "No settings configured yet."
    end

    test "displays existing settings in table", %{conn: conn} do
      setting_fixture(%{key: "app_name", value: "My Holdco"})

      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ "app_name"
      assert html =~ "My Holdco"
    end
  end

  describe "tab switching" do
    test "clicking each tab activates it, shows content, and switching closes modal", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      # Categories
      html = view |> element(~s(button[phx-value-tab="categories"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="categories"/s
      assert html =~ "Categories"
      assert html =~ "No categories yet."

      # Webhooks
      html = view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="webhooks"/s
      assert html =~ "Webhooks"
      assert html =~ "No webhooks configured yet."

      # Backups
      html = view |> element(~s(button[phx-value-tab="backups"])) |> render_click()
      assert html =~ ~r/class="tab tab-active"[^>]*phx-value-tab="backups"/s
      assert html =~ "Backup Configurations"
      assert html =~ "No backup configurations yet."

      # Go back to settings and open form, then switch to close it
      view |> element(~s(button[phx-value-tab="settings"])) |> render_click()
      view |> element("button", "Add") |> render_click()
      html = view |> element(~s(button[phx-value-tab="categories"])) |> render_click()
      refute html =~ "dialog-overlay"
    end
  end

  describe "settings CRUD - admin" do
    test "admin can add, view, and delete a setting", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, html} = live(conn, ~p"/settings")

      assert html =~ "Add Setting"

      html = view |> element("button", "Add Setting") |> render_click()
      assert html =~ "dialog-overlay"
      assert html =~ "Add/Update Setting"

      html =
        view
        |> form(~s(form[phx-submit="save_setting"]), %{
          "setting" => %{"key" => "timezone", "value" => "UTC"}
        })
        |> render_submit()

      assert html =~ "timezone"
      assert html =~ "UTC"

      setting = Holdco.Platform.list_settings() |> Enum.find(&(&1.key == "timezone"))

      html =
        view
        |> element(~s(button[phx-click="delete_setting"][phx-value-id="#{setting.id}"]))
        |> render_click()

      assert html =~ "Setting deleted"
    end
  end

  describe "categories CRUD - admin" do
    test "admin can view existing, add, and delete categories", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      cat = category_fixture(%{name: "Operating", color: "#00ff00"})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="categories"])) |> render_click()

      assert html =~ "Operating"
      assert html =~ "#00ff00"

      view |> element("button", "Add Category") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_category"]), %{
          "category" => %{"name" => "Real Estate", "color" => "#ff0000"}
        })
        |> render_submit()

      assert html =~ "Real Estate"

      html =
        view
        |> element(~s(button[phx-click="delete_category"][phx-value-id="#{cat.id}"]))
        |> render_click()

      assert html =~ "Category deleted"
    end
  end

  describe "webhooks CRUD - admin" do
    test "admin can add a webhook and delete an inactive webhook", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      wh = webhook_fixture(%{url: "https://existing.example.com/wh", is_active: false})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()

      assert html =~ "existing.example.com"

      # Delete webhook
      html =
        view
        |> element(~s(button[phx-click="delete_webhook"][phx-value-id="#{wh.id}"]))
        |> render_click()

      assert html =~ "Webhook deleted"

      # Add new webhook
      view |> element("button", "Add Webhook") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_webhook"]), %{
          "webhook" => %{"url" => "https://new.example.com/hook"}
        })
        |> render_submit()

      assert html =~ "new.example.com"
    end
  end

  describe "backups CRUD - admin" do
    test "admin can view existing, add, and delete backup configs", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      bc = backup_config_fixture(%{
        name: "Daily Prod",
        destination_path: "/var/backups",
        destination_type: "local",
        schedule: "daily",
        retention_days: 7,
        is_active: true
      })

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="backups"])) |> render_click()

      assert html =~ "Daily Prod"
      assert html =~ "/var/backups"
      assert html =~ "7 days"

      # Delete existing
      html =
        view
        |> element(~s(button[phx-click="delete_backup"][phx-value-id="#{bc.id}"]))
        |> render_click()

      assert html =~ "Backup config deleted"

      # Add new
      view |> element("button", "Add Config") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_backup"]), %{
          "backup_config" => %{
            "name" => "Nightly",
            "destination_type" => "local",
            "destination_path" => "/backups/nightly",
            "schedule" => "daily",
            "retention_days" => "30"
          }
        })
        |> render_submit()

      assert html =~ "Nightly"
    end
  end

  describe "permission guards - non-admin" do
    test "non-admin cannot see Add buttons and gets error on protected events", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/settings")

      refute html =~ "Add Setting"

      html = render_hook(view, "save_setting", %{"setting" => %{"key" => "t", "value" => "v"}})
      assert html =~ "Admin access required"

      html = render_hook(view, "delete_setting", %{"id" => "1"})
      assert html =~ "Admin access required"

      html = render_hook(view, "save_category", %{"category" => %{"name" => "test"}})
      assert html =~ "Admin access required"

      html = render_hook(view, "save_webhook", %{"webhook" => %{"url" => "https://example.com"}})
      assert html =~ "Admin access required"

      html = render_hook(view, "save_backup", %{"backup_config" => %{"name" => "test"}})
      assert html =~ "Admin access required"
    end
  end

  describe "nav active state" do
    test "settings nav link is highlighted", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/settings")

      assert html =~ ~r/href="\/settings"[^>]*class="active"/s
    end
  end

  describe "noop event" do
    test "noop does not crash the view", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      render_hook(view, "noop", %{})
      html = render(view)
      assert html =~ "Settings"
    end

    test "noop on categories tab does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="categories"])) |> render_click()
      render_hook(view, "noop", %{})
      html = render(view)
      assert html =~ "Categories"
    end
  end

  describe "users tab rendering" do
    test "users tab shows Users heading and user count", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      assert html =~ "Users"
      assert html =~ "users"
    end

    test "users tab shows current user email", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      assert html =~ user.email
    end

    test "users tab shows Email, Role, and Joined headers", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      assert html =~ "Email"
      assert html =~ "Role"
      assert html =~ "Joined"
    end

    test "non-admin sees role as tag rather than dropdown", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      assert html =~ "tag tag-ink"
      refute html =~ ~s(name="role")
    end

    test "admin sees role dropdown on users tab", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      assert html =~ ~s(name="role")
      assert html =~ ~s(phx-change="update_role")
      assert html =~ "admin"
      assert html =~ "editor"
      assert html =~ "viewer"
    end
  end

  describe "update_role event" do
    test "admin can update a user role", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="users"])) |> render_click()

      html =
        render_hook(view, "update_role", %{"user_id" => to_string(user.id), "role" => "editor"})

      assert html =~ "Role updated"
    end

    test "non-admin cannot update role", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html =
        render_hook(view, "update_role", %{"user_id" => to_string(user.id), "role" => "admin"})

      assert html =~ "Admin access required"
    end
  end

  describe "delete permission guards for non-admins" do
    test "non-admin cannot delete a category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = render_hook(view, "delete_category", %{"id" => "1"})
      assert html =~ "Admin access required"
    end

    test "non-admin cannot delete a webhook", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = render_hook(view, "delete_webhook", %{"id" => "1"})
      assert html =~ "Admin access required"
    end

    test "non-admin cannot delete a backup config", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = render_hook(view, "delete_backup", %{"id" => "1"})
      assert html =~ "Admin access required"
    end
  end

  describe "error paths for admin CRUD" do
    setup %{user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      :ok
    end

    test "save_setting with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      view |> element("button", "Add Setting") |> render_click()

      # Submit with empty key
      html =
        view
        |> form(~s(form[phx-submit="save_setting"]), %{
          "setting" => %{"key" => "", "value" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to save setting"
    end

    test "save_category with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      view |> element(~s(button[phx-value-tab="categories"])) |> render_click()
      view |> element("button", "Add Category") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_category"]), %{
          "category" => %{"name" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to add category"
    end

    test "save_webhook with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()
      view |> element("button", "Add Webhook") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_webhook"]), %{
          "webhook" => %{"url" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to add webhook"
    end

    test "save_backup with invalid data shows error", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      view |> element(~s(button[phx-value-tab="backups"])) |> render_click()
      view |> element("button", "Add Config") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_backup"]), %{
          "backup_config" => %{"name" => "", "destination_path" => ""}
        })
        |> render_submit()

      assert html =~ "Failed to add backup config"
    end
  end

  describe "handle_info" do
    test "handle_info reloads data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/settings")
      send(view.pid, :some_event)
      html = render(view)
      assert html =~ "Settings"
    end
  end

  describe "show_form and close_form" do
    test "show_form opens modal and close_form closes it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      html = render_click(view, "show_form", %{})
      assert html =~ "dialog-overlay"

      html = render_click(view, "close_form", %{})
      refute html =~ "dialog-overlay"
    end
  end
end
