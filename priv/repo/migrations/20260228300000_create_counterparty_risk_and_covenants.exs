defmodule Holdco.Repo.Migrations.CreateCounterpartyRiskAndCovenants do
  use Ecto.Migration

  def change do
    create table(:counterparty_exposures) do
      add :company_id, references(:companies, on_delete: :delete_all)
      add :counterparty_name, :string, null: false
      add :counterparty_type, :string
      add :exposure_amount, :decimal
      add :currency, :string, default: "USD"
      add :credit_rating, :string
      add :rating_agency, :string
      add :max_exposure_limit, :decimal
      add :utilization_pct, :decimal
      add :risk_score, :decimal
      add :last_review_date, :date
      add :next_review_date, :date
      add :notes, :text
      add :status, :string, default: "active"
      timestamps(type: :utc_datetime)
    end

    create table(:loan_covenants) do
      add :company_id, references(:companies, on_delete: :delete_all)
      add :liability_id, references(:liabilities, on_delete: :nilify_all)
      add :name, :string, null: false
      add :description, :text
      add :covenant_type, :string, null: false
      add :metric, :string
      add :threshold, :decimal
      add :comparison, :string
      add :upper_bound, :decimal
      add :current_value, :decimal
      add :status, :string, default: "compliant"
      add :measurement_frequency, :string, default: "quarterly"
      add :last_measured_at, :utc_datetime
      add :next_measurement_date, :date
      add :breach_count, :integer, default: 0
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:counterparty_exposures, [:company_id])
    create index(:counterparty_exposures, [:status])
    create index(:loan_covenants, [:company_id])
    create index(:loan_covenants, [:liability_id])
    create index(:loan_covenants, [:status])
  end
end
