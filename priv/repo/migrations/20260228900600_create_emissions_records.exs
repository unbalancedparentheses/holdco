defmodule Holdco.Repo.Migrations.CreateEmissionsRecords do
  use Ecto.Migration

  def change do
    create table(:emissions_records) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :reporting_year, :integer, null: false
      add :scope, :string, null: false, default: "scope_1"
      add :category, :string, null: false, default: "energy"
      add :source_description, :string
      add :quantity, :decimal
      add :unit, :string, default: "tonnes_co2e"
      add :emission_factor, :decimal
      add :co2_equivalent, :decimal
      add :methodology, :string
      add :verification_status, :string, default: "unverified"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:emissions_records, [:company_id])
    create index(:emissions_records, [:reporting_year])
    create index(:emissions_records, [:scope])
    create index(:emissions_records, [:category])
  end
end
