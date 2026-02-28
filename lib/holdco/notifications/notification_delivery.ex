defmodule Holdco.Notifications.NotificationDelivery do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notification_deliveries" do
    field :provider, :string
    field :status, :string, default: "pending"
    field :sent_at, :utc_datetime
    field :error_message, :string
    field :attempts, :integer, default: 0
    belongs_to :notification, Holdco.Notifications.Notification
    belongs_to :channel, Holdco.Notifications.NotificationChannel
    timestamps(type: :utc_datetime)
  end

  def changeset(delivery, attrs) do
    delivery
    |> cast(attrs, [:notification_id, :channel_id, :provider, :status, :sent_at, :error_message, :attempts])
    |> validate_required([:notification_id, :channel_id, :provider])
    |> validate_inclusion(:status, ~w(pending sent failed skipped))
    |> foreign_key_constraint(:notification_id)
    |> foreign_key_constraint(:channel_id)
  end
end
