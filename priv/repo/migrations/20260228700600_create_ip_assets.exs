defmodule Holdco.Repo.Migrations.CreateIpAssets do
  use Ecto.Migration

  def change do
    create table(:ip_assets) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :asset_type, :string, null: false, default: "patent"
      add :name, :string, null: false
      add :registration_number, :string
      add :jurisdiction, :string
      add :filing_date, :date
      add :grant_date, :date
      add :expiry_date, :date
      add :status, :string, null: false, default: "pending"
      add :owner_entity, :string
      add :licensees, {:array, :string}, default: []
      add :annual_cost, :decimal
      add :currency, :string, default: "USD"
      add :valuation, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ip_assets, [:company_id])
    create index(:ip_assets, [:asset_type])
    create index(:ip_assets, [:status])
    create index(:ip_assets, [:expiry_date])
  end
end
