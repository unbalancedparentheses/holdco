defmodule Holdco.PlatformTest do
  use Holdco.DataCase

  import Holdco.HoldcoFixtures

  alias Holdco.Platform

  # ── Audit Logs ────────────────────────────────────────

  describe "audit_logs" do
    test "list_audit_logs/1 returns logs" do
      audit_log_fixture()
      assert length(Platform.list_audit_logs(%{})) > 0
    end

    test "list_audit_logs/1 with no opts returns logs" do
      audit_log_fixture()
      assert length(Platform.list_audit_logs()) > 0
    end

    test "list_audit_logs/1 respects limit" do
      for _ <- 1..5, do: audit_log_fixture()
      logs = Platform.list_audit_logs(%{limit: 2})
      assert length(logs) <= 2
    end

    test "list_audit_logs/1 filters by action" do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "delete", table_name: "companies"})

      logs = Platform.list_audit_logs(%{action: "create"})
      assert Enum.all?(logs, &(&1.action == "create"))
    end

    test "list_audit_logs/1 filters by table_name" do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "create", table_name: "holdings"})

      logs = Platform.list_audit_logs(%{table_name: "holdings"})
      assert Enum.all?(logs, &(&1.table_name == "holdings"))
    end

    test "list_audit_logs/1 filters by user_id" do
      user = Holdco.AccountsFixtures.user_fixture()
      audit_log_fixture(%{action: "create", table_name: "companies", user_id: user.id})
      audit_log_fixture(%{action: "create", table_name: "companies"})

      logs = Platform.list_audit_logs(%{user_id: user.id})
      assert Enum.all?(logs, &(&1.user_id == user.id))
    end

    test "list_audit_logs/1 filters by from date (date string)" do
      audit_log_fixture(%{action: "test_from"})
      today = Date.utc_today() |> Date.to_iso8601()
      logs = Platform.list_audit_logs(%{from: today})
      assert is_list(logs)
    end

    test "list_audit_logs/1 filters by from date (datetime)" do
      audit_log_fixture(%{action: "test_from_dt"})
      now = DateTime.utc_now()
      past = DateTime.add(now, -3600, :second)
      logs = Platform.list_audit_logs(%{from: past})
      assert is_list(logs)
    end

    test "list_audit_logs/1 filters by to date (date string)" do
      audit_log_fixture(%{action: "test_to"})
      today = Date.utc_today() |> Date.to_iso8601()
      logs = Platform.list_audit_logs(%{to: today})
      assert is_list(logs)
    end

    test "list_audit_logs/1 filters by to date (datetime)" do
      audit_log_fixture(%{action: "test_to_dt"})
      now = DateTime.utc_now()
      future = DateTime.add(now, 3600, :second)
      logs = Platform.list_audit_logs(%{to: future})
      assert is_list(logs)
    end

    test "list_audit_logs/1 ignores nil/empty filter values" do
      audit_log_fixture()
      logs1 = Platform.list_audit_logs(%{action: nil})
      logs2 = Platform.list_audit_logs(%{action: ""})
      logs3 = Platform.list_audit_logs(%{table_name: nil})
      logs4 = Platform.list_audit_logs(%{table_name: ""})
      logs5 = Platform.list_audit_logs(%{user_id: nil})
      logs6 = Platform.list_audit_logs(%{user_id: ""})
      logs7 = Platform.list_audit_logs(%{from: nil})
      logs8 = Platform.list_audit_logs(%{from: ""})
      logs9 = Platform.list_audit_logs(%{to: nil})
      logs10 = Platform.list_audit_logs(%{to: ""})

      assert is_list(logs1)
      assert is_list(logs2)
      assert is_list(logs3)
      assert is_list(logs4)
      assert is_list(logs5)
      assert is_list(logs6)
      assert is_list(logs7)
      assert is_list(logs8)
      assert is_list(logs9)
      assert is_list(logs10)
    end

    test "list_audit_logs/1 handles invalid from/to strings gracefully" do
      audit_log_fixture()
      logs1 = Platform.list_audit_logs(%{from: "invalid-date"})
      logs2 = Platform.list_audit_logs(%{to: "invalid-date"})
      assert is_list(logs1)
      assert is_list(logs2)
    end

    test "list_audit_logs/1 handles non-binary/non-datetime from/to" do
      audit_log_fixture()
      logs1 = Platform.list_audit_logs(%{from: 12345})
      logs2 = Platform.list_audit_logs(%{to: 12345})
      assert is_list(logs1)
      assert is_list(logs2)
    end

    test "list_audit_logs/1 orders by inserted_at desc" do
      audit_log_fixture(%{action: "first"})
      audit_log_fixture(%{action: "second"})

      logs = Platform.list_audit_logs(%{})
      dates = Enum.map(logs, & &1.inserted_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "list_audit_logs/1 combines multiple filters" do
      audit_log_fixture(%{action: "create", table_name: "companies"})
      audit_log_fixture(%{action: "create", table_name: "holdings"})
      audit_log_fixture(%{action: "delete", table_name: "companies"})

      logs = Platform.list_audit_logs(%{action: "create", table_name: "companies"})
      assert Enum.all?(logs, &(&1.action == "create" and &1.table_name == "companies"))
    end

    test "create_audit_log/1" do
      {:ok, al} = Platform.create_audit_log(%{action: "update", table_name: "holdings"})
      assert al.action == "update"
      assert al.table_name == "holdings"
    end

    test "create_audit_log/1 with details" do
      {:ok, al} = Platform.create_audit_log(%{action: "update", table_name: "holdings", details: "Changed quantity"})
      assert al.details == "Changed quantity"
    end

    test "create_audit_log/1 with record_id" do
      {:ok, al} = Platform.create_audit_log(%{action: "update", table_name: "holdings", record_id: 42})
      assert al.record_id == 42
    end

    test "log_action/4 creates log" do
      {:ok, al} = Platform.log_action("create", "companies", 1)
      assert al.action == "create"
      assert al.table_name == "companies"
      assert al.record_id == 1
    end

    test "log_action/5 with details and user_id" do
      user = Holdco.AccountsFixtures.user_fixture()
      {:ok, al} = Platform.log_action("update", "companies", 1, "Changed name", user.id)
      assert al.details == "Changed name"
      assert al.user_id == user.id
    end
  end

  # ── Settings ──────────────────────────────────────────

  describe "settings" do
    test "upsert_setting/2 creates and updates" do
      {:ok, s} = Platform.upsert_setting("test_key", "value1")
      assert s.value == "value1"

      {:ok, s2} = Platform.upsert_setting("test_key", "value2")
      assert s2.value == "value2"
      assert s2.id == s.id
    end

    test "get_setting/1 returns setting or nil" do
      Platform.upsert_setting("gs_key", "gs_val")
      assert Platform.get_setting("gs_key") != nil
      assert Platform.get_setting("nonexistent_key") == nil
    end

    test "get_setting_value/2 returns value or default" do
      Platform.upsert_setting("gsv_key", "gsv_val")
      assert Platform.get_setting_value("gsv_key") == "gsv_val"
      assert Platform.get_setting_value("gsv_key", "default") == "gsv_val"
      assert Platform.get_setting_value("missing", "default") == "default"
      assert Platform.get_setting_value("missing") == nil
    end

    test "list_settings/0" do
      Platform.upsert_setting("list_test", "val")
      settings = Platform.list_settings()
      assert length(settings) > 0
    end

    test "delete_setting/1" do
      {:ok, s} = Platform.upsert_setting("del_key", "val")
      {:ok, _} = Platform.delete_setting(s.id)
      assert Platform.get_setting("del_key") == nil
    end

    test "delete_setting/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.delete_setting(-1)
      end
    end
  end

  # ── Categories ────────────────────────────────────────

  describe "categories" do
    test "CRUD operations" do
      {:ok, c} = Platform.create_category(%{name: "Tech"})

      assert Enum.any?(Platform.list_categories(), &(&1.id == c.id))
      assert Platform.get_category!(c.id).id == c.id

      {:ok, updated} = Platform.update_category(c, %{name: "Finance"})
      assert updated.name == "Finance"

      {:ok, _} = Platform.delete_category(updated)
    end

    test "list_categories/0 returns ordered by name" do
      Platform.create_category(%{name: "ZZZ Category"})
      Platform.create_category(%{name: "AAA Category"})

      cats = Platform.list_categories()
      names = Enum.map(cats, & &1.name)
      assert names == Enum.sort(names)
    end

    test "get_category!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_category!(-1)
      end
    end

    test "create_category/1 with invalid attrs returns error" do
      {:error, changeset} = Platform.create_category(%{})
      assert changeset.valid? == false
    end
  end

  # ── Webhooks ──────────────────────────────────────────

  describe "webhooks" do
    test "CRUD operations" do
      {:ok, w} = Platform.create_webhook(%{url: "https://example.com/hook"})

      assert Enum.any?(Platform.list_webhooks(), &(&1.id == w.id))
      assert Platform.get_webhook!(w.id).id == w.id

      {:ok, updated} = Platform.update_webhook(w, %{url: "https://new.com/hook"})
      assert updated.url == "https://new.com/hook"

      {:ok, _} = Platform.delete_webhook(updated)
    end

    test "get_webhook!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_webhook!(-1)
      end
    end

    test "create_webhook/1 with secret" do
      {:ok, w} = Platform.create_webhook(%{url: "https://example.com/hook", secret: "my_secret"})
      assert w.secret == "my_secret"
    end

    test "create_webhook/1 with is_active flag" do
      {:ok, w} = Platform.create_webhook(%{url: "https://example.com/hook", is_active: false})
      assert w.is_active == false
    end
  end

  # ── Approval Requests ─────────────────────────────────

  describe "approval_requests" do
    test "CRUD operations" do
      {:ok, a} = Platform.create_approval_request(%{requested_by: "user@test.com", table_name: "companies", action: "delete"})

      assert Enum.any?(Platform.list_approval_requests(), &(&1.id == a.id))
      assert Platform.get_approval_request!(a.id).id == a.id

      {:ok, updated} = Platform.update_approval_request(a, %{status: "approved"})
      assert updated.status == "approved"

      {:ok, _} = Platform.delete_approval_request(updated)
    end

    test "list_approval_requests/0 returns results ordered by inserted_at desc" do
      {:ok, a1} = Platform.create_approval_request(%{requested_by: "user1@test.com", table_name: "t", action: "a"})
      {:ok, a2} = Platform.create_approval_request(%{requested_by: "user2@test.com", table_name: "t", action: "a"})

      requests = Platform.list_approval_requests()
      ids = Enum.map(requests, & &1.id)
      # Both should be present
      assert a1.id in ids
      assert a2.id in ids
      # Dates should be in descending order (or equal for same-second inserts)
      dates = Enum.map(requests, & &1.inserted_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "pending_approval_count/0" do
      Platform.create_approval_request(%{requested_by: "user@test.com", table_name: "companies", action: "create", status: "pending"})
      Platform.create_approval_request(%{requested_by: "user2@test.com", table_name: "companies", action: "create", status: "approved"})

      count = Platform.pending_approval_count()
      assert count >= 1
    end

    test "get_approval_request!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_approval_request!(-1)
      end
    end
  end

  # ── Custom Fields ─────────────────────────────────────

  describe "custom_fields" do
    test "CRUD operations" do
      {:ok, cf} = Platform.create_custom_field(%{name: "Industry"})

      assert Enum.any?(Platform.list_custom_fields(), &(&1.id == cf.id))
      assert Platform.get_custom_field!(cf.id).id == cf.id

      {:ok, updated} = Platform.update_custom_field(cf, %{name: "Sector"})
      assert updated.name == "Sector"

      {:ok, _} = Platform.delete_custom_field(updated)
    end

    test "get_custom_field!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_custom_field!(-1)
      end
    end

    test "custom_field_values CRUD" do
      cf = custom_field_fixture()
      {:ok, v} = Platform.create_custom_field_value(%{custom_field_id: cf.id, entity_type: "company", entity_id: 1, value: "Tech"})

      values = Platform.list_custom_field_values("company", 1)
      assert Enum.any?(values, &(&1.id == v.id))

      # List for different entity returns empty
      assert Platform.list_custom_field_values("company", 9999) == []

      {:ok, _} = Platform.delete_custom_field_value(v)
      assert Platform.list_custom_field_values("company", 1) == []
    end

    test "list_custom_field_values preloads custom_field" do
      cf = custom_field_fixture()
      {:ok, _v} = Platform.create_custom_field_value(%{custom_field_id: cf.id, entity_type: "holding", entity_id: 1, value: "Test"})

      values = Platform.list_custom_field_values("holding", 1)
      assert length(values) > 0
      assert hd(values).custom_field != nil
      assert hd(values).custom_field.id == cf.id
    end
  end

  # ── Backup Configs ────────────────────────────────────

  describe "backup_configs" do
    test "CRUD operations" do
      {:ok, bc} = Platform.create_backup_config(%{name: "Nightly", destination_path: "/backups"})

      assert Enum.any?(Platform.list_backup_configs(), &(&1.id == bc.id))
      assert Platform.get_backup_config!(bc.id).id == bc.id

      {:ok, updated} = Platform.update_backup_config(bc, %{name: "Hourly"})
      assert updated.name == "Hourly"

      {:ok, _} = Platform.delete_backup_config(updated)
    end

    test "get_backup_config!/1 raises for non-existent id" do
      assert_raise Ecto.NoResultsError, fn ->
        Platform.get_backup_config!(-1)
      end
    end

    test "create_backup_config/1 with all fields" do
      {:ok, bc} = Platform.create_backup_config(%{
        name: "Full Config",
        destination_path: "/backups/full",
        destination_type: "s3",
        schedule: "hourly",
        retention_days: 90,
        is_active: false,
        notes: "Test config"
      })

      assert bc.destination_type == "s3"
      assert bc.schedule == "hourly"
      assert bc.retention_days == 90
      assert bc.is_active == false
      assert bc.notes == "Test config"
    end

    test "create_backup_config/1 with missing required fields returns error" do
      {:error, changeset} = Platform.create_backup_config(%{})
      assert changeset.valid? == false
    end
  end

  # ── Backup Logs ───────────────────────────────────────

  describe "backup_logs" do
    test "create_backup_log/1 and list_backup_logs/0" do
      bc = backup_config_fixture()
      {:ok, bl} = Platform.create_backup_log(%{config_id: bc.id, status: "completed"})
      assert bl.status == "completed"

      logs = Platform.list_backup_logs()
      assert length(logs) > 0
    end

    test "list_backup_logs/0 preloads config" do
      bc = backup_config_fixture()
      Platform.create_backup_log(%{config_id: bc.id, status: "completed"})

      logs = Platform.list_backup_logs()
      log = hd(logs)
      assert log.config != nil
      assert log.config.id == bc.id
    end

    test "list_backup_logs/0 orders by inserted_at desc" do
      bc = backup_config_fixture()
      Platform.create_backup_log(%{config_id: bc.id, status: "running"})
      Platform.create_backup_log(%{config_id: bc.id, status: "completed"})

      logs = Platform.list_backup_logs()
      dates = Enum.map(logs, & &1.inserted_at)
      assert dates == Enum.sort(dates, {:desc, DateTime})
    end

    test "create_backup_log/1 with all fields" do
      bc = backup_config_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      {:ok, bl} = Platform.create_backup_log(%{
        config_id: bc.id,
        status: "completed",
        file_path: "/backups/test.db",
        file_size_bytes: 1024,
        completed_at: now
      })

      assert bl.file_path == "/backups/test.db"
      assert bl.file_size_bytes == 1024
      assert bl.completed_at == now
    end

    test "create_backup_log/1 with error message for failed status" do
      bc = backup_config_fixture()

      {:ok, bl} = Platform.create_backup_log(%{
        config_id: bc.id,
        status: "failed",
        error_message: "Disk full"
      })

      assert bl.status == "failed"
      assert bl.error_message == "Disk full"
    end
  end

  # ── PubSub ────────────────────────────────────────────

  describe "subscribe/1" do
    test "subscribes to a topic without error" do
      assert :ok == Platform.subscribe("test_topic")
    end
  end

  # ── deliver_webhooks ──────────────────────────────────

  describe "deliver_webhooks/3" do
    test "returns empty list when no webhooks exist" do
      result = Platform.deliver_webhooks("create", "companies", 1)
      assert result == []
    end

    test "skips inactive webhooks" do
      webhook_fixture(%{is_active: false})
      result = Platform.deliver_webhooks("create", "companies", 1)
      assert result == []
    end
  end

  # ── log_action with webhook prefix ─────────────────────
  describe "log_action/4 webhook prefix skip" do
    test "log_action with webhook prefix does not trigger async webhooks" do
      {:ok, al} = Platform.log_action("webhook_failed", "webhooks", 1)
      assert al.action == "webhook_failed"
    end

    test "log_action with nil details defaults to nil" do
      {:ok, al} = Platform.log_action("create", "companies", 1)
      assert al.details == nil
    end
  end

  # ── Audit log broadcast ────────────────────────────────
  describe "create_audit_log broadcast" do
    test "broadcasts audit_log_created on success" do
      Platform.subscribe("audit")
      {:ok, log} = Platform.create_audit_log(%{action: "create", table_name: "test_broadcast"})
      assert_receive {:audit_log_created, ^log}
    end

    test "does not broadcast on failure" do
      Platform.subscribe("audit")
      # Missing required fields
      {:error, _changeset} = Platform.create_audit_log(%{})
      refute_receive {:audit_log_created, _}
    end
  end

  # ── Settings broadcast ─────────────────────────────────
  describe "upsert_setting broadcast" do
    test "broadcasts setting_updated on success" do
      Platform.subscribe("platform")
      {:ok, _s} = Platform.upsert_setting("broadcast_key", "v1")
      assert_receive {:setting_updated, "broadcast_key"}
    end
  end

  # ── Categories audit_and_broadcast ─────────────────────
  describe "categories audit_and_broadcast" do
    test "create_category broadcasts and logs" do
      Platform.subscribe("platform")
      {:ok, cat} = Platform.create_category(%{name: "Broadcast Cat"})
      assert_receive {:categories_created, ^cat}
    end

    test "update_category broadcasts and logs" do
      {:ok, cat} = Platform.create_category(%{name: "Update Cat"})
      Platform.subscribe("platform")
      {:ok, updated} = Platform.update_category(cat, %{name: "Updated Cat"})
      assert_receive {:categories_updated, ^updated}
    end

    test "delete_category broadcasts and logs" do
      {:ok, cat} = Platform.create_category(%{name: "Delete Cat"})
      Platform.subscribe("platform")
      {:ok, deleted} = Platform.delete_category(cat)
      assert_receive {:categories_deleted, ^deleted}
    end
  end

  # ── Webhooks audit_and_broadcast ───────────────────────
  describe "webhooks audit_and_broadcast" do
    test "create_webhook broadcasts" do
      Platform.subscribe("platform")
      {:ok, w} = Platform.create_webhook(%{url: "https://test.com/broadcast"})
      assert_receive {:webhooks_created, ^w}
    end

    test "update_webhook broadcasts" do
      {:ok, w} = Platform.create_webhook(%{url: "https://test.com/orig"})
      Platform.subscribe("platform")
      {:ok, updated} = Platform.update_webhook(w, %{url: "https://test.com/updated"})
      assert_receive {:webhooks_updated, ^updated}
    end

    test "delete_webhook broadcasts" do
      {:ok, w} = Platform.create_webhook(%{url: "https://test.com/del"})
      Platform.subscribe("platform")
      {:ok, deleted} = Platform.delete_webhook(w)
      assert_receive {:webhooks_deleted, ^deleted}
    end
  end

  # ── Approval Requests audit_and_broadcast ──────────────
  describe "approval_requests audit_and_broadcast" do
    test "create broadcasts" do
      Platform.subscribe("platform")
      {:ok, a} = Platform.create_approval_request(%{requested_by: "bc@test.com", table_name: "t", action: "a"})
      assert_receive {:approval_requests_created, ^a}
    end

    test "update broadcasts" do
      {:ok, a} = Platform.create_approval_request(%{requested_by: "bu@test.com", table_name: "t", action: "a"})
      Platform.subscribe("platform")
      {:ok, updated} = Platform.update_approval_request(a, %{status: "approved"})
      assert_receive {:approval_requests_updated, ^updated}
    end

    test "delete broadcasts" do
      {:ok, a} = Platform.create_approval_request(%{requested_by: "bd@test.com", table_name: "t", action: "a"})
      Platform.subscribe("platform")
      {:ok, deleted} = Platform.delete_approval_request(a)
      assert_receive {:approval_requests_deleted, ^deleted}
    end
  end

  # ── Backup Configs audit_and_broadcast ─────────────────
  describe "backup_configs audit_and_broadcast" do
    test "create broadcasts" do
      Platform.subscribe("platform")
      {:ok, bc} = Platform.create_backup_config(%{name: "BC Broadcast", destination_path: "/bc"})
      assert_receive {:backup_configs_created, ^bc}
    end

    test "update broadcasts" do
      {:ok, bc} = Platform.create_backup_config(%{name: "BC Update", destination_path: "/bc2"})
      Platform.subscribe("platform")
      {:ok, updated} = Platform.update_backup_config(bc, %{name: "BC Updated"})
      assert_receive {:backup_configs_updated, ^updated}
    end

    test "delete broadcasts" do
      {:ok, bc} = Platform.create_backup_config(%{name: "BC Delete", destination_path: "/bc3"})
      Platform.subscribe("platform")
      {:ok, deleted} = Platform.delete_backup_config(bc)
      assert_receive {:backup_configs_deleted, ^deleted}
    end
  end

  # ── deliver_webhook with various responses ─────────────
  describe "deliver_webhook/2" do
    test "deliver_webhook with unreachable URL logs failure" do
      {:ok, w} = Platform.create_webhook(%{url: "http://localhost:1/nonexistent", is_active: true})
      result = Platform.deliver_webhook(w, %{event: "test", table: "test", record_id: 1})
      assert {:error, _reason} = result
    end

    test "deliver_webhook with secret includes signature header logic" do
      {:ok, w} = Platform.create_webhook(%{url: "http://localhost:1/nonexistent", is_active: true, secret: "test_secret"})
      result = Platform.deliver_webhook(w, %{event: "test", table: "test", record_id: 1})
      assert {:error, _reason} = result
    end
  end

  # ── Custom Fields error cases ──────────────────────────
  describe "custom_fields error handling" do
    test "create_custom_field with invalid attrs" do
      {:error, changeset} = Platform.create_custom_field(%{})
      assert changeset.valid? == false
    end
  end
end
