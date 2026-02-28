defmodule Holdco.Repo.Migrations.CreateCustomDashboards do
  use Ecto.Migration

  def change do
    create table(:custom_dashboards) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :layout, :map, default: %{}
      add :is_default, :boolean, default: false
      add :is_shared, :boolean, default: false
      add :widgets, {:array, :map}, default: []
      add :theme, :string, default: "light"
      add :refresh_interval_seconds, :integer, default: 300
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:custom_dashboards, [:user_id])
    create index(:custom_dashboards, [:is_shared])
  end
end
