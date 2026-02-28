defmodule Holdco.Repo.Migrations.CreateCharitableGifts do
  use Ecto.Migration

  def change do
    create table(:charitable_gifts) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :recipient_name, :string, null: false
      add :recipient_type, :string, default: "501c3"
      add :ein_number, :string
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :gift_type, :string, default: "cash"
      add :fair_market_value, :decimal
      add :cost_basis, :decimal
      add :gift_date, :date, null: false
      add :tax_year, :integer
      add :tax_deductible, :boolean, default: true
      add :deduction_limit_pct, :decimal
      add :acknowledgment_received, :boolean, default: false
      add :acknowledgment_date, :date
      add :pledge_amount, :decimal
      add :pledge_fulfilled, :boolean, default: false
      add :restricted_purpose, :string
      add :grant_agreement_id, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:charitable_gifts, [:company_id])
    create index(:charitable_gifts, [:gift_type])
    create index(:charitable_gifts, [:tax_year])
    create index(:charitable_gifts, [:gift_date])
  end
end
