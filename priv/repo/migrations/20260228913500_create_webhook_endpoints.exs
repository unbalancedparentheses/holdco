defmodule Holdco.Repo.Migrations.CreateWebhookEndpoints do
  use Ecto.Migration

  def change do
    create table(:webhook_endpoints) do
      add :url, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :secret_key, :string
      add :events, {:array, :string}, default: []
      add :is_active, :boolean, default: true
      add :failure_count, :integer, default: 0
      add :max_retries, :integer, default: 3
      add :last_triggered_at, :utc_datetime
      add :last_response_code, :integer
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:webhook_endpoints, [:is_active])
  end
end
