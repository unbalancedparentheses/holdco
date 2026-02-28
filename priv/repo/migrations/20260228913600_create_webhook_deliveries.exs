defmodule Holdco.Repo.Migrations.CreateWebhookDeliveries do
  use Ecto.Migration

  def change do
    create table(:webhook_deliveries) do
      add :endpoint_id, references(:webhook_endpoints, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :payload, :map, default: %{}
      add :response_code, :integer
      add :response_body, :text
      add :status, :string, default: "pending"
      add :attempts, :integer, default: 0
      add :next_retry_at, :utc_datetime
      add :delivered_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:webhook_deliveries, [:endpoint_id])
    create index(:webhook_deliveries, [:status])
  end
end
