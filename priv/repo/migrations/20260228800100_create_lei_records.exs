defmodule Holdco.Repo.Migrations.CreateLeiRecords do
  use Ecto.Migration

  def change do
    create table(:lei_records) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :lei_code, :string, size: 20, null: false
      add :registration_status, :string, null: false, default: "pending"
      add :initial_registration_date, :date
      add :last_renewal_date, :date
      add :next_renewal_date, :date
      add :managing_lou, :string
      add :legal_name, :string
      add :jurisdiction, :string
      add :registration_authority, :string
      add :entity_status, :string, default: "active"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:lei_records, [:company_id])
    create unique_index(:lei_records, [:lei_code])
    create index(:lei_records, [:registration_status])
    create index(:lei_records, [:next_renewal_date])
  end
end
