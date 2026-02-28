defmodule Holdco.Repo.Migrations.CreateAmlAlerts do
  use Ecto.Migration

  def change do
    create table(:aml_alerts) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :transaction_id, :string
      add :alert_type, :string, null: false, default: "large_transaction"
      add :severity, :string, null: false, default: "medium"
      add :amount, :decimal
      add :currency, :string, default: "USD"
      add :description, :text
      add :rule_triggered, :string
      add :status, :string, null: false, default: "open"
      add :assigned_to, :string
      add :resolution_notes, :text
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:aml_alerts, [:company_id])
    create index(:aml_alerts, [:status])
    create index(:aml_alerts, [:severity])
    create index(:aml_alerts, [:alert_type])
  end
end
