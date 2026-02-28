defmodule Holdco.Repo.Migrations.CreateKycRecords do
  use Ecto.Migration

  def change do
    create table(:kyc_records) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :entity_name, :string, null: false
      add :entity_type, :string, null: false, default: "individual"
      add :risk_level, :string, null: false, default: "low"
      add :verification_status, :string, null: false, default: "not_started"
      add :id_type, :string
      add :id_number, :string
      add :id_expiry_date, :date
      add :country_of_residence, :string
      add :nationality, :string
      add :pep_status, :boolean, default: false
      add :sanctions_checked, :boolean, default: false
      add :last_review_date, :date
      add :next_review_date, :date
      add :reviewer_notes, :text
      add :documents, {:array, :string}, default: []

      timestamps(type: :utc_datetime)
    end

    create index(:kyc_records, [:company_id])
    create index(:kyc_records, [:verification_status])
    create index(:kyc_records, [:risk_level])
    create index(:kyc_records, [:next_review_date])
  end
end
