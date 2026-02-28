defmodule Holdco.Repo.Migrations.CreateCorporateActions do
  use Ecto.Migration

  def change do
    create table(:corporate_actions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :action_type, :string, null: false
      add :announcement_date, :string
      add :record_date, :string
      add :effective_date, :string
      add :completion_date, :string
      add :description, :string
      add :ratio_numerator, :integer
      add :ratio_denominator, :integer
      add :price_per_share, :decimal
      add :total_value, :decimal
      add :currency, :string, default: "USD"
      add :status, :string, null: false, default: "announced"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:corporate_actions, [:company_id])
    create index(:corporate_actions, [:action_type])
    create index(:corporate_actions, [:status])
  end
end
