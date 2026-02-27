defmodule Holdco.Repo.Migrations.CreateProjectMilestones do
  use Ecto.Migration

  def change do
    create table(:project_milestones) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :due_date, :string
      add :status, :string, default: "pending"
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:project_milestones, [:project_id])
  end
end
