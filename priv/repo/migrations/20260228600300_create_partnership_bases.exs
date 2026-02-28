defmodule Holdco.Repo.Migrations.CreatePartnershipBases do
  use Ecto.Migration

  def change do
    create table(:partnership_bases) do
      add :partner_name, :string, null: false
      add :tax_year, :integer, null: false
      add :beginning_basis, :decimal, default: 0
      add :capital_contributions, :decimal, default: 0
      add :share_of_income, :decimal, default: 0
      add :share_of_losses, :decimal, default: 0
      add :distributions_received, :decimal, default: 0
      add :special_allocations, :decimal, default: 0
      add :section_754_adjustments, :decimal, default: 0
      add :ending_basis, :decimal, default: 0
      add :at_risk_amount, :decimal, default: 0
      add :passive_activity_amount, :decimal, default: 0
      add :notes, :text
      add :company_id, references(:companies, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create index(:partnership_bases, [:company_id])
    create index(:partnership_bases, [:partner_name])
    create index(:partnership_bases, [:tax_year])
    create index(:partnership_bases, [:company_id, :partner_name, :tax_year], unique: true)
  end
end
