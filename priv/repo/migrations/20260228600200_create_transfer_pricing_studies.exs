defmodule Holdco.Repo.Migrations.CreateTransferPricingStudies do
  use Ecto.Migration

  def change do
    create table(:transfer_pricing_studies) do
      add :study_name, :string, null: false
      add :fiscal_year, :integer, null: false
      add :related_party_name, :string, null: false
      add :transaction_type, :string, default: "goods"
      add :transaction_amount, :decimal, default: 0
      add :currency, :string, default: "USD"
      add :method, :string, default: "cup"
      add :arm_length_range_low, :decimal
      add :arm_length_range_high, :decimal
      add :tested_party_margin, :decimal
      add :conclusion, :string, default: "within_range"
      add :adjustment_needed, :decimal, default: 0
      add :documentation_status, :string, default: "not_started"
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:transfer_pricing_studies, [:company_id])
    create index(:transfer_pricing_studies, [:fiscal_year])
    create index(:transfer_pricing_studies, [:method])
  end
end
