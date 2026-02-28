defmodule Holdco.Repo.Migrations.CreateEstatePlans do
  use Ecto.Migration

  def change do
    create table(:estate_plans) do
      add :family_charter_id, references(:family_charters, on_delete: :nilify_all)
      add :plan_name, :string, null: false
      add :plan_type, :string, null: false
      add :principal_name, :string, null: false
      add :attorney_name, :string
      add :executor_name, :string
      add :status, :string, null: false, default: "draft"
      add :effective_date, :date
      add :last_reviewed_date, :date
      add :next_review_date, :date
      add :key_provisions, :text
      add :asset_summary, :map, default: %{}
      add :estimated_estate_value, :decimal
      add :currency, :string, default: "USD"
      add :tax_implications, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:estate_plans, [:family_charter_id])
    create index(:estate_plans, [:plan_type])
    create index(:estate_plans, [:status])
    create index(:estate_plans, [:next_review_date])
  end
end
