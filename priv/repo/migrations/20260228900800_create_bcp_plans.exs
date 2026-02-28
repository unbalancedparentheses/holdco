defmodule Holdco.Repo.Migrations.CreateBcpPlans do
  use Ecto.Migration

  def change do
    create table(:bcp_plans) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :plan_name, :string, null: false
      add :plan_type, :string, null: false, default: "business_continuity"
      add :version, :string
      add :status, :string, null: false, default: "draft"
      add :approved_by, :string
      add :approved_date, :date
      add :last_tested_date, :date
      add :next_test_date, :date
      add :test_result, :string, default: "not_tested"
      add :rto_hours, :integer
      add :rpo_hours, :integer
      add :key_contacts, {:array, :map}, default: []
      add :critical_systems, {:array, :string}, default: []
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:bcp_plans, [:company_id])
    create index(:bcp_plans, [:plan_type])
    create index(:bcp_plans, [:status])
    create index(:bcp_plans, [:next_test_date])
  end
end
