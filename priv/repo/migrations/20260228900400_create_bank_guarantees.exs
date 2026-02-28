defmodule Holdco.Repo.Migrations.CreateBankGuarantees do
  use Ecto.Migration

  def change do
    create table(:bank_guarantees) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :guarantee_type, :string, null: false, default: "performance"
      add :issuing_bank, :string, null: false
      add :beneficiary, :string, null: false
      add :reference_number, :string
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :issue_date, :date
      add :expiry_date, :date
      add :status, :string, null: false, default: "active"
      add :annual_fee_pct, :decimal
      add :collateral_description, :text
      add :purpose, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:bank_guarantees, [:company_id])
    create index(:bank_guarantees, [:status])
    create index(:bank_guarantees, [:guarantee_type])
    create index(:bank_guarantees, [:expiry_date])
  end
end
