defmodule Holdco.Repo.Migrations.AddNotificationChannelFields do
  use Ecto.Migration

  def change do
    alter table(:notification_channels) do
      add :name, :string
      add :provider_type, :string
      add :last_sent_at, :utc_datetime
      add :failure_count, :integer, default: 0
    end
  end
end
