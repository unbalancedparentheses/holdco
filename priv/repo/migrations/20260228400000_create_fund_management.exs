defmodule Holdco.Repo.Migrations.CreateFundManagement do
  use Ecto.Migration

  def change do
    create table(:capital_calls) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :call_number, :integer
      add :call_date, :date, null: false
      add :due_date, :date
      add :total_amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :purpose, :string
      add :status, :string, default: "pending"
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:capital_call_lines) do
      add :capital_call_id, references(:capital_calls, on_delete: :delete_all), null: false
      add :investor_name, :string, null: false
      add :commitment_amount, :decimal
      add :call_amount, :decimal, null: false
      add :paid_amount, :decimal, default: 0
      add :status, :string, default: "pending"
      add :paid_date, :date
      timestamps(type: :utc_datetime)
    end

    create table(:distributions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :distribution_number, :integer
      add :distribution_date, :date, null: false
      add :total_amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :distribution_type, :string
      add :status, :string, default: "pending"
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:distribution_lines) do
      add :distribution_id, references(:distributions, on_delete: :delete_all), null: false
      add :investor_name, :string, null: false
      add :ownership_pct, :decimal
      add :gross_amount, :decimal, null: false
      add :withholding_tax, :decimal, default: 0
      add :net_amount, :decimal
      add :status, :string, default: "pending"
      timestamps(type: :utc_datetime)
    end

    create table(:waterfall_tiers) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :tier_order, :integer, null: false
      add :name, :string, null: false
      add :description, :text
      add :tier_type, :string
      add :hurdle_rate, :decimal
      add :split_lp_pct, :decimal
      add :split_gp_pct, :decimal
      timestamps(type: :utc_datetime)
    end

    create table(:k1_reports) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :tax_year, :integer, null: false
      add :investor_name, :string, null: false
      add :ordinary_income, :decimal, default: 0
      add :short_term_capital_gains, :decimal, default: 0
      add :long_term_capital_gains, :decimal, default: 0
      add :tax_exempt_income, :decimal, default: 0
      add :section_179_deduction, :decimal, default: 0
      add :other_deductions, :decimal, default: 0
      add :total_distributions, :decimal, default: 0
      add :beginning_capital, :decimal, default: 0
      add :ending_capital, :decimal, default: 0
      add :status, :string, default: "draft"
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:capital_calls, [:company_id])
    create index(:capital_call_lines, [:capital_call_id])
    create index(:distributions, [:company_id])
    create index(:distribution_lines, [:distribution_id])
    create index(:waterfall_tiers, [:company_id])
    create index(:k1_reports, [:company_id])
    create index(:k1_reports, [:tax_year])
  end
end
