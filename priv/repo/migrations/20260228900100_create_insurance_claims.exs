defmodule Holdco.Repo.Migrations.CreateInsuranceClaims do
  use Ecto.Migration

  def change do
    create table(:insurance_claims) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :policy_id, references(:insurance_policies, on_delete: :nilify_all)
      add :claim_number, :string, null: false
      add :incident_date, :date
      add :filing_date, :date
      add :claim_type, :string, null: false, default: "other"
      add :description, :text
      add :claimed_amount, :decimal
      add :settled_amount, :decimal
      add :deductible, :decimal
      add :status, :string, null: false, default: "filed"
      add :adjuster_name, :string
      add :adjuster_contact, :string
      add :settlement_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:insurance_claims, [:company_id])
    create index(:insurance_claims, [:policy_id])
    create index(:insurance_claims, [:status])
    create index(:insurance_claims, [:claim_type])
    create unique_index(:insurance_claims, [:claim_number])
  end
end
