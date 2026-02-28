defmodule Holdco.Repo.Migrations.CreateQuickActions do
  use Ecto.Migration

  def change do
    create table(:quick_actions) do
      add :name, :string, null: false
      add :description, :string
      add :action_type, :string, null: false
      add :target_path, :string, null: false
      add :icon, :string
      add :category, :string
      add :search_keywords, {:array, :string}, default: []
      add :sort_order, :integer, default: 0
      add :is_enabled, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:quick_actions, [:name])
    create index(:quick_actions, [:category])
    create index(:quick_actions, [:is_enabled])
  end
end
