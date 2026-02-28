defmodule Holdco.Platform.WebhookEndpoint do
  use Ecto.Schema
  import Ecto.Changeset

  schema "webhook_endpoints" do
    field :url, :string
    field :name, :string
    field :description, :string
    field :secret_key, :string
    field :events, {:array, :string}, default: []
    field :is_active, :boolean, default: true
    field :failure_count, :integer, default: 0
    field :max_retries, :integer, default: 3
    field :last_triggered_at, :utc_datetime
    field :last_response_code, :integer
    field :notes, :string

    has_many :deliveries, Holdco.Platform.WebhookDelivery, foreign_key: :endpoint_id

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook_endpoint, attrs) do
    webhook_endpoint
    |> cast(attrs, [
      :url, :name, :description, :secret_key, :events, :is_active,
      :failure_count, :max_retries, :last_triggered_at, :last_response_code, :notes
    ])
    |> validate_required([:url, :name])
  end
end
