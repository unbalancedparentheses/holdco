defmodule Holdco.Platform.WebhookDelivery do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(pending delivered failed retrying)

  schema "webhook_deliveries" do
    field :event_type, :string
    field :payload, :map, default: %{}
    field :response_code, :integer
    field :response_body, :string
    field :status, :string, default: "pending"
    field :attempts, :integer, default: 0
    field :next_retry_at, :utc_datetime
    field :delivered_at, :utc_datetime

    belongs_to :endpoint, Holdco.Platform.WebhookEndpoint

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook_delivery, attrs) do
    webhook_delivery
    |> cast(attrs, [
      :endpoint_id, :event_type, :payload, :response_code, :response_body,
      :status, :attempts, :next_retry_at, :delivered_at
    ])
    |> validate_required([:endpoint_id, :event_type])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:endpoint_id)
  end

  def statuses, do: @statuses
end
