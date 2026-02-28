defmodule Holdco.Repo.Migrations.CreateHealthScores do
  use Ecto.Migration

  def change do
    create table(:health_scores) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :score_date, :date, null: false
      add :overall_score, :decimal, null: false
      add :liquidity_score, :decimal
      add :profitability_score, :decimal
      add :compliance_score, :decimal
      add :governance_score, :decimal
      add :risk_score, :decimal
      add :operational_score, :decimal
      add :components, :map, default: %{}
      add :trend, :string, default: "stable"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:health_scores, [:company_id])
    create index(:health_scores, [:score_date])
    create index(:health_scores, [:trend])
  end
end
