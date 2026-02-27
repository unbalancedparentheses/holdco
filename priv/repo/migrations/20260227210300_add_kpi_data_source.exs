defmodule Holdco.Repo.Migrations.AddKpiDataSource do
  use Ecto.Migration

  def change do
    alter table(:kpis) do
      add :data_source, :string  # nil = manual, "revenue", "expenses", "net_income", "cash_balance", "nav", "liability_total"
    end
  end
end
