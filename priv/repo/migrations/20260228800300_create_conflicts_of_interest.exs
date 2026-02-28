defmodule Holdco.Repo.Migrations.CreateConflictsOfInterest do
  use Ecto.Migration

  def change do
    create table(:conflicts_of_interest) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :declarant_name, :string, null: false
      add :declarant_role, :string, null: false
      add :conflict_type, :string, null: false
      add :description, :text, null: false
      add :parties_involved, :string
      add :potential_impact, :string
      add :declared_date, :date, null: false
      add :review_date, :date
      add :status, :string, null: false, default: "declared"
      add :mitigation_plan, :text
      add :reviewer_name, :string
      add :review_notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:conflicts_of_interest, [:company_id])
    create index(:conflicts_of_interest, [:declarant_name])
    create index(:conflicts_of_interest, [:status])
    create index(:conflicts_of_interest, [:conflict_type])
  end
end
