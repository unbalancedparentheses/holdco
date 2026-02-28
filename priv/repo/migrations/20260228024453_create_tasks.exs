defmodule Holdco.Repo.Migrations.CreateTasks do
  use Ecto.Migration

  def change do
    create table(:tasks) do
      add :title, :string, null: false
      add :description, :text
      add :status, :string, default: "open", null: false
      add :priority, :string, default: "medium", null: false
      add :due_date, :string
      add :completed_at, :utc_datetime
      add :linked_entity_type, :string
      add :linked_entity_id, :bigint
      add :created_from, :string
      add :notes, :text
      add :assignee_id, references(:users, on_delete: :nilify_all)
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:tasks, [:company_id])
    create index(:tasks, [:assignee_id])
    create index(:tasks, [:status])
    create index(:tasks, [:due_date])
  end
end
