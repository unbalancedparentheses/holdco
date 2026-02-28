defmodule Holdco.Repo.Migrations.CreateNotificationChannels do
  use Ecto.Migration

  def change do
    create table(:notification_channels) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :is_active, :boolean, default: true
      add :config, :map
      add :event_types, {:array, :string}
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:notification_deliveries) do
      add :notification_id, references(:notifications, on_delete: :delete_all), null: false
      add :channel_id, references(:notification_channels, on_delete: :delete_all), null: false
      add :provider, :string, null: false
      add :status, :string, default: "pending"
      add :sent_at, :utc_datetime
      add :error_message, :text
      add :attempts, :integer, default: 0
      timestamps(type: :utc_datetime)
    end

    create index(:notification_channels, [:user_id])
    create index(:notification_channels, [:provider])
    create index(:notification_deliveries, [:notification_id])
    create index(:notification_deliveries, [:channel_id])
    create index(:notification_deliveries, [:status])
  end
end
