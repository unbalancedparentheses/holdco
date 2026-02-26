defmodule Holdco.Platform.BackupLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "backup_logs" do
    field :status, :string, default: "running"
    field :file_path, :string
    field :file_size_bytes, :integer
    field :error_message, :string
    field :completed_at, :utc_datetime

    belongs_to :config, Holdco.Platform.BackupConfig

    timestamps(type: :utc_datetime)
  end

  def changeset(backup_log, attrs) do
    backup_log
    |> cast(attrs, [:config_id, :status, :file_path, :file_size_bytes, :error_message, :completed_at])
    |> validate_required([:config_id])
  end
end
