defmodule Holdco.Repo.Migrations.CreateLitigations do
  use Ecto.Migration

  def change do
    create table(:litigations) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :case_name, :string, null: false
      add :case_number, :string
      add :court_or_tribunal, :string
      add :jurisdiction, :string
      add :case_type, :string, null: false, default: "civil"
      add :party_role, :string, null: false, default: "defendant"
      add :opposing_party, :string
      add :filing_date, :date
      add :status, :string, null: false, default: "active"
      add :estimated_exposure, :decimal
      add :actual_outcome_amount, :decimal
      add :currency, :string, default: "USD"
      add :lead_counsel, :string
      add :next_hearing_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:litigations, [:company_id])
    create index(:litigations, [:status])
    create index(:litigations, [:case_type])
    create index(:litigations, [:next_hearing_date])
  end
end
