defmodule Holdco.Repo.Migrations.CreatePlugins do
  use Ecto.Migration

  def change do
    create table(:plugins) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :description, :text
      add :version, :string
      add :author, :string
      add :plugin_type, :string, null: false
      add :status, :string, null: false, default: "installed"
      add :config, :map, default: %{}
      add :permissions_required, {:array, :string}, default: []
      add :entry_module, :string
      add :installed_at, :utc_datetime
      add :last_activated_at, :utc_datetime
      add :error_log, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:plugins, [:slug])
    create index(:plugins, [:plugin_type])
    create index(:plugins, [:status])
  end
end
