defmodule Holdco.Repo.Migrations.CreateNotificationLogs do
  use Ecto.Migration

  def change do
    create table(:notification_logs) do
      add :channel_id, references(:notification_channels, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :message, :text, null: false
      add :status, :string, default: "pending", null: false
      add :error_message, :text
      add :sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:notification_logs, [:channel_id])
    create index(:notification_logs, [:event_type])
    create index(:notification_logs, [:status])
  end
end
