defmodule Holdco.Repo.Migrations.CreateAlertRulesAndAlerts do
  use Ecto.Migration

  def change do
    create table(:alert_rules) do
      add :name, :string, null: false
      add :description, :text
      add :metric, :string, null: false
      add :condition, :string, null: false
      add :threshold, :decimal, null: false
      add :target, :string
      add :severity, :string, default: "warning"
      add :is_active, :boolean, default: true
      add :cooldown_minutes, :integer, default: 60
      add :last_triggered_at, :utc_datetime
      add :company_id, references(:companies, on_delete: :delete_all)
      add :created_by_id, references(:users, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create index(:alert_rules, [:company_id])
    create index(:alert_rules, [:is_active])
    create index(:alert_rules, [:metric])

    create table(:alerts) do
      add :alert_rule_id, references(:alert_rules, on_delete: :delete_all), null: false
      add :metric_value, :decimal
      add :threshold_value, :decimal
      add :message, :text
      add :severity, :string
      add :status, :string, default: "unread"
      add :acknowledged_at, :utc_datetime
      add :acknowledged_by_id, references(:users, on_delete: :nilify_all)
      add :resolved_at, :utc_datetime
      timestamps(type: :utc_datetime)
    end

    create index(:alerts, [:alert_rule_id])
    create index(:alerts, [:status])
    create index(:alerts, [:severity])
    create index(:alerts, [:inserted_at])
  end
end
