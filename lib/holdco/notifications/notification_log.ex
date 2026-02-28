defmodule Holdco.Notifications.NotificationLog do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(sent failed pending)

  schema "notification_logs" do
    field :event_type, :string
    field :message, :string
    field :status, :string, default: "pending"
    field :error_message, :string
    field :sent_at, :utc_datetime

    belongs_to :channel, Holdco.Notifications.NotificationChannel

    timestamps(type: :utc_datetime)
  end

  def changeset(log, attrs) do
    log
    |> cast(attrs, [:channel_id, :event_type, :message, :status, :error_message, :sent_at])
    |> validate_required([:channel_id, :event_type, :message])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:channel_id)
  end

  def statuses, do: @statuses
end
