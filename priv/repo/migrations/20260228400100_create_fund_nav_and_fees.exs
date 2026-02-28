defmodule Holdco.Repo.Migrations.CreateFundNavAndFees do
  use Ecto.Migration

  def change do
    create table(:fund_navs) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :nav_date, :date, null: false
      add :total_assets, :decimal
      add :total_liabilities, :decimal
      add :net_asset_value, :decimal
      add :nav_per_unit, :decimal
      add :units_outstanding, :decimal
      add :currency, :string, default: "USD"
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:investor_statements) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :investor_name, :string, null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :beginning_balance, :decimal, default: 0
      add :contributions, :decimal, default: 0
      add :distributions, :decimal, default: 0
      add :income_allocation, :decimal, default: 0
      add :expense_allocation, :decimal, default: 0
      add :unrealized_gain_loss, :decimal, default: 0
      add :ending_balance, :decimal, default: 0
      add :ownership_pct, :decimal
      add :irr, :decimal
      add :moic, :decimal
      add :status, :string, default: "draft"
      add :sent_at, :utc_datetime
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:fund_fees) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :fee_type, :string, null: false
      add :description, :string
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :period_start, :date
      add :period_end, :date
      add :basis, :string
      add :rate_pct, :decimal
      add :calculation_basis_amount, :decimal
      add :status, :string, default: "accrued"
      add :paid_date, :date
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:fund_navs, [:company_id])
    create index(:fund_navs, [:nav_date])
    create unique_index(:fund_navs, [:company_id, :nav_date])
    create index(:investor_statements, [:company_id])
    create index(:investor_statements, [:investor_name])
    create index(:fund_fees, [:company_id])
    create index(:fund_fees, [:fee_type])
    create index(:fund_fees, [:status])
  end
end
