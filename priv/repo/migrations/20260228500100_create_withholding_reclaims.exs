defmodule Holdco.Repo.Migrations.CreateWithholdingReclaims do
  use Ecto.Migration

  def change do
    create table(:withholding_reclaims) do
      add :jurisdiction, :string, null: false
      add :tax_year, :integer, null: false
      add :income_type, :string, null: false
      add :gross_amount, :decimal, null: false
      add :withholding_rate, :decimal, null: false
      add :amount_withheld, :decimal, null: false
      add :treaty_rate, :decimal
      add :reclaimable_amount, :decimal, default: 0
      add :reclaimed_amount, :decimal, default: 0
      add :status, :string, default: "pending"
      add :filed_date, :string
      add :received_date, :string
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:withholding_reclaims, [:company_id])
    create index(:withholding_reclaims, [:status])
    create index(:withholding_reclaims, [:jurisdiction])
  end
end
