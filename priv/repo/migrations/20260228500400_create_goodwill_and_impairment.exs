defmodule Holdco.Repo.Migrations.CreateGoodwillAndImpairment do
  use Ecto.Migration

  def change do
    create table(:goodwill) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :acquisition_name, :string, null: false
      add :acquisition_date, :string
      add :original_amount, :decimal, null: false
      add :accumulated_impairment, :decimal, default: 0
      add :carrying_value, :decimal, null: false
      add :reporting_unit, :string
      add :last_test_date, :string
      add :next_test_date, :string
      add :status, :string, default: "active"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:goodwill, [:company_id])
    create index(:goodwill, [:status])

    create table(:impairment_tests) do
      add :goodwill_id, references(:goodwill, on_delete: :delete_all), null: false
      add :test_date, :string, null: false
      add :fair_value, :decimal, null: false
      add :carrying_amount, :decimal, null: false
      add :impairment_amount, :decimal, default: 0
      add :method, :string, null: false
      add :discount_rate, :decimal
      add :growth_rate, :decimal
      add :assumptions, :text
      add :result, :string, null: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:impairment_tests, [:goodwill_id])
    create index(:impairment_tests, [:test_date])
  end
end
