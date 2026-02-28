defmodule Holdco.Repo.Migrations.CreateDividendPoliciesAndTaxProvisions do
  use Ecto.Migration

  def change do
    create table(:dividend_policies) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :policy_type, :string, null: false
      add :target_payout_ratio, :decimal
      add :fixed_amount, :decimal
      add :growth_rate, :decimal
      add :frequency, :string, default: "quarterly"
      add :min_retained_earnings, :decimal
      add :max_payout_ratio, :decimal
      add :is_active, :boolean, default: true
      add :last_dividend_date, :date
      add :next_dividend_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create table(:tax_provisions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :tax_year, :integer, null: false
      add :jurisdiction, :string, null: false
      add :provision_type, :string, null: false
      add :tax_type, :string, default: "income"
      add :taxable_income, :decimal, default: 0
      add :tax_rate, :decimal
      add :tax_amount, :decimal
      add :status, :string, default: "estimated"
      add :due_date, :date
      add :paid_date, :date
      add :paid_amount, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create table(:deferred_taxes) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :tax_year, :integer, null: false
      add :description, :string, null: false
      add :deferred_type, :string, null: false
      add :source, :string
      add :book_basis, :decimal
      add :tax_basis, :decimal
      add :temporary_difference, :decimal
      add :tax_rate, :decimal
      add :deferred_amount, :decimal
      add :is_current, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:dividend_policies, [:company_id])
    create index(:tax_provisions, [:company_id])
    create index(:tax_provisions, [:tax_year])
    create index(:tax_provisions, [:status])
    create index(:deferred_taxes, [:company_id])
    create index(:deferred_taxes, [:tax_year])
    create index(:deferred_taxes, [:deferred_type])
  end
end
