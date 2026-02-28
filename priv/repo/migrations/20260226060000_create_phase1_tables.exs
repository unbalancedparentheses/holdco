defmodule Holdco.Repo.Migrations.CreatePhase1Tables do
  use Ecto.Migration

  def change do
    # Fixed Assets for depreciation tracking
    create table(:fixed_assets) do
      add :name, :string, null: false
      add :purchase_date, :string
      add :purchase_price, :decimal
      add :useful_life_months, :integer
      add :salvage_value, :decimal, default: 0.0
      add :depreciation_method, :string, default: "straight_line"
      add :currency, :string, default: "USD"
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :account_id, references(:accounts, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:fixed_assets, [:company_id])
    create index(:fixed_assets, [:account_id])

    # Leases for lease accounting (IFRS 16 / ASC 842)
    create table(:leases) do
      add :lessor, :string, null: false
      add :asset_description, :string
      add :start_date, :string
      add :end_date, :string
      add :monthly_payment, :decimal
      add :discount_rate, :decimal, default: 0.05
      add :lease_type, :string, default: "operating"
      add :currency, :string, default: "USD"
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:leases, [:company_id])

    # KPIs for tracking key performance indicators
    create table(:kpis) do
      add :name, :string, null: false
      add :metric_type, :string, default: "currency"
      add :target_value, :decimal
      add :threshold_value, :decimal
      add :unit, :string
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:kpis, [:company_id])

    # KPI Snapshots for historical tracking
    create table(:kpi_snapshots) do
      add :current_value, :decimal
      add :trend, :string
      add :date, :string
      add :kpi_id, references(:kpis, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:kpi_snapshots, [:kpi_id])

    # Segments for segment reporting
    create table(:segments) do
      add :name, :string, null: false
      add :segment_type, :string, default: "business"
      add :description, :text
      add :company_id, references(:companies, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:segments, [:company_id])

    # Report Templates for management report builder
    create table(:report_templates) do
      add :name, :string, null: false
      add :sections, :text, default: "[]"
      add :company_ids, :text, default: "[]"
      add :date_from, :string
      add :date_to, :string
      add :frequency, :string, default: "monthly"
      add :user_id, references(:users, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    create index(:report_templates, [:user_id])
  end
end
