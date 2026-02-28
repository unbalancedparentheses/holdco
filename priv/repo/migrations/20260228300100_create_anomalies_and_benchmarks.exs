defmodule Holdco.Repo.Migrations.CreateAnomaliesAndBenchmarks do
  use Ecto.Migration

  def change do
    create table(:anomalies) do
      add :company_id, references(:companies, on_delete: :delete_all)
      add :entity_type, :string, null: false
      add :entity_id, :integer
      add :anomaly_type, :string, null: false
      add :severity, :string, default: "medium"
      add :description, :text
      add :detected_value, :decimal
      add :expected_range_low, :decimal
      add :expected_range_high, :decimal
      add :deviation_pct, :decimal
      add :status, :string, default: "open"
      add :resolved_at, :utc_datetime
      add :resolved_by_id, references(:users, on_delete: :nilify_all)
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create table(:benchmarks) do
      add :name, :string, null: false
      add :description, :text
      add :benchmark_type, :string, null: false
      add :ticker, :string
      add :data_points, :map
      add :is_active, :boolean, default: true

      timestamps(type: :utc_datetime)
    end

    create table(:benchmark_comparisons) do
      add :benchmark_id, references(:benchmarks, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all)
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :portfolio_return, :decimal
      add :benchmark_return, :decimal
      add :alpha, :decimal
      add :tracking_error, :decimal
      add :information_ratio, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:anomalies, [:company_id])
    create index(:anomalies, [:status])
    create index(:anomalies, [:anomaly_type])
    create index(:anomalies, [:severity])
    create index(:benchmarks, [:benchmark_type])
    create index(:benchmark_comparisons, [:benchmark_id])
    create index(:benchmark_comparisons, [:company_id])
  end
end
