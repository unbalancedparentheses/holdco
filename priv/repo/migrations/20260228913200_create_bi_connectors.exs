defmodule Holdco.Repo.Migrations.CreateBiConnectors do
  use Ecto.Migration

  def change do
    create table(:bi_connectors) do
      add :name, :string, null: false
      add :connector_type, :string, null: false
      add :connection_string_encrypted, :text
      add :api_key_encrypted, :text
      add :dataset_name, :string
      add :refresh_frequency, :string, default: "manual"
      add :last_sync_at, :utc_datetime
      add :sync_status, :string, default: "idle"
      add :tables_included, {:array, :string}, default: []
      add :row_limit, :integer
      add :format, :string, default: "json"
      add :is_active, :boolean, default: true
      add :error_log, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:bi_connectors, [:connector_type])
    create index(:bi_connectors, [:is_active])
  end
end
