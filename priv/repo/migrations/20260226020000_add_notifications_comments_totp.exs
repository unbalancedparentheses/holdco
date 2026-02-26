defmodule Holdco.Repo.Migrations.AddNotificationsCommentsTotp do
  use Ecto.Migration

  def change do
    # Notifications
    create table(:notifications) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :body, :text
      add :type, :string, default: "info"
      add :read_at, :utc_datetime
      add :entity_type, :string
      add :entity_id, :integer
      add :action_url, :string
      timestamps(type: :utc_datetime)
    end

    create index(:notifications, [:user_id])
    create index(:notifications, [:read_at])

    # Comments (polymorphic)
    create table(:comments) do
      add :user_id, references(:users, on_delete: :nilify_all)
      add :entity_type, :string, null: false
      add :entity_id, :integer, null: false
      add :body, :text, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:comments, [:entity_type, :entity_id])
    create index(:comments, [:user_id])

    # TOTP 2FA on users
    alter table(:users) do
      add :totp_secret, :binary
      add :totp_enabled, :boolean, default: false
    end
  end
end
