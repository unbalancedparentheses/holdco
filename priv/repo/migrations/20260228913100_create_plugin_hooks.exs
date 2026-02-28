defmodule Holdco.Repo.Migrations.CreatePluginHooks do
  use Ecto.Migration

  def change do
    create table(:plugin_hooks) do
      add :plugin_id, references(:plugins, on_delete: :delete_all), null: false
      add :hook_point, :string, null: false
      add :entity_type, :string
      add :handler_function, :string, null: false
      add :priority, :integer, default: 50
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:plugin_hooks, [:plugin_id])
    create index(:plugin_hooks, [:hook_point])
  end
end
