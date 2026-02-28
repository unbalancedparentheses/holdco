defmodule Holdco.Repo.Migrations.CreateCollaborationSessions do
  use Ecto.Migration

  def change do
    create table(:collaboration_sessions) do
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :started_at, :utc_datetime, null: false
      add :last_active_at, :utc_datetime, null: false
      add :is_active, :boolean, default: true
      add :notes, {:array, :map}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:collaboration_sessions, [:entity_type, :entity_id])
    create index(:collaboration_sessions, [:user_id])
    create index(:collaboration_sessions, [:is_active])
  end
end
