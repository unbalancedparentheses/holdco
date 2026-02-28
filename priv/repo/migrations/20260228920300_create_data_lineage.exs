defmodule Holdco.Repo.Migrations.CreateDataLineage do
  use Ecto.Migration

  def change do
    create table(:data_lineage) do
      add :source_type, :string, null: false
      add :source_identifier, :string
      add :target_entity_type, :string, null: false
      add :target_entity_id, :integer, null: false
      add :transformation, :text
      add :confidence, :string, default: "high"
      add :verified, :boolean, default: false, null: false
      add :verified_by_id, references(:users, on_delete: :nilify_all)
      add :verified_at, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:data_lineage, [:source_type])
    create index(:data_lineage, [:target_entity_type, :target_entity_id])
    create index(:data_lineage, [:verified])
    create index(:data_lineage, [:confidence])
  end
end
