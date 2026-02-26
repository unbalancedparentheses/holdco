defmodule Holdco.Repo.Migrations.AddAccountingFields do
  use Ecto.Migration

  def change do
    # Add external_id to accounts for QBO sync
    alter table(:accounts) do
      add :external_id, :string
    end

    create index(:accounts, [:external_id])

    # Add external_id to journal_entries for QBO sync
    alter table(:journal_entries) do
      add :external_id, :string
    end

    create index(:journal_entries, [:external_id])

    # Integrations table for QuickBooks (and future integrations)
    create table(:integrations) do
      add :provider, :string, null: false
      add :realm_id, :string
      add :access_token, :text
      add :refresh_token, :text
      add :token_expires_at, :utc_datetime
      add :last_synced_at, :utc_datetime
      add :status, :string, default: "disconnected"
      add :metadata, :text

      timestamps(type: :utc_datetime)
    end

    create unique_index(:integrations, [:provider])
  end
end
