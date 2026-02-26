defmodule Holdco.Platform do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Platform.{Setting, Category, AuditLog, Webhook, ApprovalRequest, CustomField, CustomFieldValue, BackupConfig, BackupLog}

  # Audit Log
  def list_audit_logs(opts \\ %{}) do
    AuditLog
    |> order_by([a], desc: a.inserted_at)
    |> limit(^Map.get(opts, :limit, 100))
    |> Repo.all()
  end

  def create_audit_log(attrs) do
    %AuditLog{}
    |> AuditLog.changeset(attrs)
    |> Repo.insert()
    |> tap(fn
      {:ok, log} -> broadcast("audit", {:audit_log_created, log})
      _ -> :ok
    end)
  end

  def log_action(action, table_name, record_id, details \\ nil, user_id \\ nil) do
    create_audit_log(%{
      action: action,
      table_name: table_name,
      record_id: record_id,
      details: details,
      user_id: user_id
    })
  end

  # Settings
  def list_settings, do: Repo.all(Setting)
  def get_setting(key), do: Repo.get_by(Setting, key: key)
  def get_setting_value(key, default \\ nil) do
    case get_setting(key) do
      %Setting{value: value} -> value
      nil -> default
    end
  end

  def upsert_setting(key, value) do
    case get_setting(key) do
      nil -> %Setting{} |> Setting.changeset(%{key: key, value: value}) |> Repo.insert()
      setting -> setting |> Setting.changeset(%{value: value}) |> Repo.update()
    end
    |> tap(fn {:ok, _} -> broadcast("platform", {:setting_updated, key}); _ -> :ok end)
  end

  def delete_setting(id) when is_integer(id) do
    Repo.get!(Setting, id) |> Repo.delete()
  end

  # Categories
  def list_categories, do: Repo.all(from c in Category, order_by: c.name)
  def get_category!(id), do: Repo.get!(Category, id)
  def create_category(attrs) do
    %Category{} |> Category.changeset(attrs) |> Repo.insert()
    |> audit_and_broadcast("categories", "create")
  end
  def update_category(%Category{} = cat, attrs) do
    cat |> Category.changeset(attrs) |> Repo.update()
    |> audit_and_broadcast("categories", "update")
  end
  def delete_category(%Category{} = cat) do
    Repo.delete(cat) |> audit_and_broadcast("categories", "delete")
  end

  # Webhooks
  def list_webhooks, do: Repo.all(Webhook)
  def get_webhook!(id), do: Repo.get!(Webhook, id)
  def create_webhook(attrs), do: %Webhook{} |> Webhook.changeset(attrs) |> Repo.insert() |> audit_and_broadcast("webhooks", "create")
  def update_webhook(%Webhook{} = w, attrs), do: w |> Webhook.changeset(attrs) |> Repo.update() |> audit_and_broadcast("webhooks", "update")
  def delete_webhook(%Webhook{} = w), do: Repo.delete(w) |> audit_and_broadcast("webhooks", "delete")

  # Approval Requests
  def list_approval_requests, do: Repo.all(from a in ApprovalRequest, order_by: [desc: a.inserted_at])
  def get_approval_request!(id), do: Repo.get!(ApprovalRequest, id)
  def create_approval_request(attrs), do: %ApprovalRequest{} |> ApprovalRequest.changeset(attrs) |> Repo.insert() |> audit_and_broadcast("approval_requests", "create")
  def update_approval_request(%ApprovalRequest{} = a, attrs), do: a |> ApprovalRequest.changeset(attrs) |> Repo.update() |> audit_and_broadcast("approval_requests", "update")
  def delete_approval_request(%ApprovalRequest{} = a), do: Repo.delete(a) |> audit_and_broadcast("approval_requests", "delete")

  # Custom Fields
  def list_custom_fields, do: Repo.all(CustomField)
  def get_custom_field!(id), do: Repo.get!(CustomField, id)
  def create_custom_field(attrs), do: %CustomField{} |> CustomField.changeset(attrs) |> Repo.insert()
  def update_custom_field(%CustomField{} = cf, attrs), do: cf |> CustomField.changeset(attrs) |> Repo.update()
  def delete_custom_field(%CustomField{} = cf), do: Repo.delete(cf)

  # Custom Field Values
  def list_custom_field_values(entity_type, entity_id) do
    from(v in CustomFieldValue, where: v.entity_type == ^entity_type and v.entity_id == ^entity_id, preload: [:custom_field])
    |> Repo.all()
  end
  def create_custom_field_value(attrs), do: %CustomFieldValue{} |> CustomFieldValue.changeset(attrs) |> Repo.insert()
  def delete_custom_field_value(%CustomFieldValue{} = v), do: Repo.delete(v)

  # Backup Configs
  def list_backup_configs, do: Repo.all(BackupConfig)
  def get_backup_config!(id), do: Repo.get!(BackupConfig, id)
  def create_backup_config(attrs), do: %BackupConfig{} |> BackupConfig.changeset(attrs) |> Repo.insert() |> audit_and_broadcast("backup_configs", "create")
  def update_backup_config(%BackupConfig{} = bc, attrs), do: bc |> BackupConfig.changeset(attrs) |> Repo.update() |> audit_and_broadcast("backup_configs", "update")
  def delete_backup_config(%BackupConfig{} = bc), do: Repo.delete(bc) |> audit_and_broadcast("backup_configs", "delete")

  # Backup Logs
  def list_backup_logs, do: Repo.all(from l in BackupLog, order_by: [desc: l.inserted_at], preload: [:config])
  def create_backup_log(attrs), do: %BackupLog{} |> BackupLog.changeset(attrs) |> Repo.insert()

  # PubSub
  def subscribe(topic), do: Phoenix.PubSub.subscribe(Holdco.PubSub, topic)
  defp broadcast(topic, message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, topic, message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        log_action(action, table, record.id)
        broadcast("platform", {String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}
      error -> error
    end
  end
end
