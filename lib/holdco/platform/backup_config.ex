defmodule Holdco.Platform.BackupConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "backup_configs" do
    field :name, :string
    field :destination_type, :string, default: "local"
    field :destination_path, :string
    field :schedule, :string, default: "daily"
    field :retention_days, :integer, default: 30
    field :is_active, :boolean, default: true
    field :last_backup_at, :utc_datetime
    field :notes, :string

    has_many :logs, Holdco.Platform.BackupLog, foreign_key: :config_id

    timestamps(type: :utc_datetime)
  end

  def changeset(backup_config, attrs) do
    backup_config
    |> cast(attrs, [
      :name,
      :destination_type,
      :destination_path,
      :schedule,
      :retention_days,
      :is_active,
      :last_backup_at,
      :notes
    ])
    |> validate_required([:name, :destination_path])
  end
end
