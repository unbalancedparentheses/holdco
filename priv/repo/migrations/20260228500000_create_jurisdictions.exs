defmodule Holdco.Repo.Migrations.CreateJurisdictions do
  use Ecto.Migration

  def change do
    create table(:jurisdictions) do
      add :name, :string, null: false
      add :country_code, :string, null: false
      add :tax_rate, :decimal, null: false
      add :tax_type, :string, null: false
      add :effective_date, :string
      add :expiry_date, :string
      add :notes, :text
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:jurisdictions, [:country_code])
    create index(:jurisdictions, [:tax_type])
    create index(:jurisdictions, [:is_active])
  end
end
