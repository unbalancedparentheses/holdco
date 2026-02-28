defmodule Holdco.Repo.Migrations.CreateSecurityKeys do
  use Ecto.Migration

  def change do
    create table(:security_keys) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :credential_id, :string, null: false
      add :public_key, :text, null: false
      add :sign_count, :integer, default: 0
      add :aaguid, :string
      add :transports, {:array, :string}, default: []
      add :registered_at, :utc_datetime
      add :last_used_at, :utc_datetime
      add :is_active, :boolean, default: true
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:security_keys, [:user_id])
    create unique_index(:security_keys, [:credential_id])
  end
end
