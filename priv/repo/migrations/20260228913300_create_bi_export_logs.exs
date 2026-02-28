defmodule Holdco.Repo.Migrations.CreateBiExportLogs do
  use Ecto.Migration

  def change do
    create table(:bi_export_logs) do
      add :connector_id, references(:bi_connectors, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime
      add :rows_exported, :integer
      add :tables_exported, {:array, :string}, default: []
      add :status, :string, null: false
      add :error_message, :text
      add :file_size_bytes, :integer

      timestamps(type: :utc_datetime)
    end

    create index(:bi_export_logs, [:connector_id])
    create index(:bi_export_logs, [:status])
  end
end
