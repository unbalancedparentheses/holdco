defmodule Holdco.Repo.Migrations.CreateTrustAccounts do
  use Ecto.Migration

  def change do
    create table(:trust_accounts) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :trust_name, :string, null: false
      add :trust_type, :string, null: false, default: "revocable"
      add :trustee_name, :string, null: false
      add :grantor_name, :string
      add :beneficiaries, {:array, :map}, default: []
      add :jurisdiction, :string
      add :date_established, :date
      add :corpus_value, :decimal
      add :currency, :string, default: "USD"
      add :distribution_schedule, :string, default: "quarterly"
      add :last_distribution_date, :date
      add :next_distribution_date, :date
      add :tax_id, :string
      add :status, :string, null: false, default: "active"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:trust_accounts, [:company_id])
    create index(:trust_accounts, [:trust_type])
    create index(:trust_accounts, [:status])
  end
end
