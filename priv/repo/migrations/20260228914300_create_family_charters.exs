defmodule Holdco.Repo.Migrations.CreateFamilyCharters do
  use Ecto.Migration

  def change do
    create table(:family_charters) do
      add :family_name, :string, null: false
      add :version, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :mission_statement, :text
      add :values, {:array, :string}, default: []
      add :decision_making_process, :text
      add :succession_plan, :text
      add :education_policy, :text
      add :employment_policy, :text
      add :distribution_policy, :text
      add :conflict_resolution, :text
      add :meeting_schedule, :string
      add :next_review_date, :date
      add :approved_by, {:array, :string}, default: []
      add :approved_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:family_charters, [:status])
  end
end
