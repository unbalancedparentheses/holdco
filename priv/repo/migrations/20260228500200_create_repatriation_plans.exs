defmodule Holdco.Repo.Migrations.CreateRepatriationPlans do
  use Ecto.Migration

  def change do
    create table(:repatriation_plans) do
      add :source_jurisdiction, :string, null: false
      add :target_jurisdiction, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :mechanism, :string, null: false
      add :withholding_tax_rate, :decimal, default: 0
      add :withholding_tax_amount, :decimal, default: 0
      add :effective_tax_rate, :decimal, default: 0
      add :net_amount, :decimal, default: 0
      add :planned_date, :string
      add :status, :string, default: "draft"
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:repatriation_plans, [:company_id])
    create index(:repatriation_plans, [:status])
    create index(:repatriation_plans, [:source_jurisdiction])
    create index(:repatriation_plans, [:target_jurisdiction])
  end
end
