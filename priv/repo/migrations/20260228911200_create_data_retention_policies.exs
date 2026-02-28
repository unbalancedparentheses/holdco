defmodule Holdco.Repo.Migrations.CreateDataRetentionPolicies do
  use Ecto.Migration

  def change do
    create table(:data_retention_policies) do
      add :name, :string, null: false
      add :description, :text
      add :data_category, :string, null: false
      add :retention_period_days, :integer, null: false
      add :legal_basis, :string, null: false
      add :action_on_expiry, :string, null: false
      add :is_active, :boolean, default: true
      add :last_applied_at, :utc_datetime
      add :next_scheduled_at, :utc_datetime
      add :affected_tables, {:array, :string}, default: []
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:data_retention_policies, [:data_category])
    create index(:data_retention_policies, [:is_active])
  end
end
