defmodule HoldcoWeb.SettingsLiveTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

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


  describe "users tab rendering" do
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

  # ------------------------------------------------------------------
  # AI tab rendering and save_ai event
  # ------------------------------------------------------------------

  describe "AI tab" do
    test "admin can save AI settings", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="ai"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_ai"]), %{
          "ai" => %{
            "provider" => "anthropic",
            "api_key" => "sk-test-key-12345",
            "model" => "claude-sonnet-4-20250514"
          }
        })
        |> render_submit()

      assert html =~ "AI settings saved"
    end

  end

  # ------------------------------------------------------------------
  # Admin CRUD — additional operations
  # ------------------------------------------------------------------

  describe "admin save_ai with empty fields" do
    test "save_ai with empty provider does not crash", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="ai"])) |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_ai"]), %{
          "ai" => %{
            "provider" => "",
            "api_key" => "",
            "model" => ""
          }
        })
        |> render_submit()

      # With all empty values, nothing gets upserted, results in empty list which passes Enum.all?
      assert html =~ "AI settings saved"
    end
  end

  describe "admin category CRUD with color" do
    test "admin can add a category with custom color", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="categories"])) |> render_click()
      view |> element("button", "Add Category") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_category"]), %{
          "category" => %{"name" => "Holdings", "color" => "#3366ff"}
        })
        |> render_submit()

      assert html =~ "Category added"
      assert html =~ "Holdings"
      assert html =~ "#3366ff"
    end
  end

  # ------------------------------------------------------------------
  # Webhook events field
  # ------------------------------------------------------------------

  describe "webhook events" do
    test "webhook form shows event checkboxes", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      {:ok, view, _html} = live(conn, ~p"/settings")

      view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()
      html = view |> element("button", "Add Webhook") |> render_click()

      assert html =~ "Subscribe to"
      assert html =~ "create"
      assert html =~ "update"
      assert html =~ "delete"
    end

    test "webhook with events shows event list", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      webhook_fixture(%{url: "https://events.example.com/wh", events: Jason.encode!(["create", "delete"])})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()

      assert html =~ "create"
      assert html =~ "delete"
    end

    test "webhook with empty events shows All events", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      webhook_fixture(%{url: "https://allempty.example.com/wh", events: "[]"})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="webhooks"])) |> render_click()

      assert html =~ "All events"
    end
  end

  # ------------------------------------------------------------------
  # Settings upsert behavior
  # ------------------------------------------------------------------

  describe "settings upsert" do
    test "saving a setting with the same key updates it", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      setting_fixture(%{key: "test_key", value: "original_value"})

      {:ok, view, _html} = live(conn, ~p"/settings")

      assert render(view) =~ "original_value"

      view |> element("button", "Add Setting") |> render_click()

      html =
        view
        |> form(~s(form[phx-submit="save_setting"]), %{
          "setting" => %{"key" => "test_key", "value" => "updated_value"}
        })
        |> render_submit()

      assert html =~ "Setting saved"
      assert html =~ "updated_value"
    end
  end

  # ------------------------------------------------------------------
  # Backup config display
  # ------------------------------------------------------------------

  describe "backup config display" do
    test "shows active status for active backup config", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      backup_config_fixture(%{name: "Active Backup", is_active: true, destination_type: "s3", destination_path: "/s3/bucket"})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="backups"])) |> render_click()

      assert html =~ "Active Backup"
      assert html =~ "s3"
      assert html =~ "Yes"
    end

    test "shows inactive status for inactive backup config", %{conn: conn, user: user} do
      Holdco.Accounts.set_user_role(user, "admin")
      backup_config_fixture(%{name: "Inactive Backup", is_active: false})

      {:ok, view, _html} = live(conn, ~p"/settings")
      html = view |> element(~s(button[phx-value-tab="backups"])) |> render_click()

      assert html =~ "Inactive Backup"
      assert html =~ "No"
    end
  end

end
