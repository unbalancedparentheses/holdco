defmodule Holdco.Repo.Migrations.CreateRegulatoryChanges do
  use Ecto.Migration

  def change do
    create table(:regulatory_changes) do
      add :title, :string, null: false
      add :jurisdiction, :string, null: false
      add :regulatory_body, :string
      add :change_type, :string, null: false
      add :effective_date, :date
      add :description, :text
      add :impact_assessment, :string, default: "low"
      add :affected_entities, {:array, :string}, default: []
      add :status, :string, default: "monitoring"
      add :assigned_to, :string
      add :action_items, {:array, :map}, default: []
      add :source_url, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:regulatory_changes, [:jurisdiction])
    create index(:regulatory_changes, [:status])
    create index(:regulatory_changes, [:impact_assessment])
    create index(:regulatory_changes, [:change_type])
  end
end
