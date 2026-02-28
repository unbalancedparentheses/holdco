defmodule Holdco.Repo.Migrations.CreateRegulatoryCapital do
  use Ecto.Migration

  def change do
    create table(:regulatory_capital) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :reporting_date, :date, null: false
      add :framework, :string, null: false, default: "basel_iii"
      add :tier1_capital, :decimal
      add :tier2_capital, :decimal
      add :total_capital, :decimal
      add :risk_weighted_assets, :decimal
      add :capital_ratio, :decimal
      add :minimum_required_ratio, :decimal
      add :buffer_required, :decimal
      add :surplus_or_deficit, :decimal
      add :currency, :string, default: "USD"
      add :status, :string, null: false, default: "compliant"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:regulatory_capital, [:company_id])
    create index(:regulatory_capital, [:reporting_date])
    create index(:regulatory_capital, [:framework])
    create index(:regulatory_capital, [:status])
  end
end
