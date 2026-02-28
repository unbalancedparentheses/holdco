defmodule Holdco.Repo.Migrations.CreateStressTests do
  use Ecto.Migration

  def change do
    create table(:stress_tests) do
      add :name, :string, null: false
      add :description, :text
      add :status, :string, default: "draft"
      add :shocks, :map, default: %{}
      add :results, :map
      add :run_at, :utc_datetime
      add :company_id, references(:companies, on_delete: :delete_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:stress_tests, [:company_id])
    create index(:stress_tests, [:created_by_id])
    create index(:stress_tests, [:status])

    create table(:liquidity_coverages) do
      add :calculation_date, :date, null: false
      add :hqla_level1, :decimal, precision: 20, scale: 2, default: 0
      add :hqla_level2a, :decimal, precision: 20, scale: 2, default: 0
      add :hqla_level2b, :decimal, precision: 20, scale: 2, default: 0
      add :total_hqla, :decimal, precision: 20, scale: 2, default: 0
      add :net_cash_outflows_30d, :decimal, precision: 20, scale: 2, default: 0
      add :lcr_ratio, :decimal, precision: 10, scale: 2, default: 0
      add :status, :string, default: "adequate"
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:liquidity_coverages, [:company_id])
    create index(:liquidity_coverages, [:calculation_date])
    create index(:liquidity_coverages, [:status])
  end
end
