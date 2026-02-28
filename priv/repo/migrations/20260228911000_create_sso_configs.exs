defmodule Holdco.Repo.Migrations.CreateSsoConfigs do
  use Ecto.Migration

  def change do
    create table(:sso_configs) do
      add :name, :string, null: false
      add :provider_type, :string, null: false
      add :entity_id, :string
      add :sso_url, :string
      add :slo_url, :string
      add :certificate, :text
      add :metadata_url, :string
      add :client_id, :string
      add :client_secret_encrypted, :string
      add :scopes, :string
      add :attribute_mapping, :map, default: %{}
      add :auto_provision_users, :boolean, default: false
      add :default_role, :string
      add :is_active, :boolean, default: true
      add :last_synced_at, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:sso_configs, [:provider_type])
    create index(:sso_configs, [:is_active])
  end
end
