defmodule Holdco.Repo.Migrations.CreateSuccessionPlans do
  use Ecto.Migration

  def change do
    create table(:succession_plans) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :position_title, :string, null: false
      add :current_holder, :string, null: false
      add :successor_candidates, {:array, :map}, default: []
      add :timeline, :string, default: "long_term"
      add :status, :string, null: false, default: "active"
      add :trigger_events, {:array, :string}, default: []
      add :last_reviewed_date, :date
      add :next_review_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:succession_plans, [:company_id])
    create index(:succession_plans, [:status])
    create index(:succession_plans, [:timeline])
  end
end
