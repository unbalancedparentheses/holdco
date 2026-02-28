defmodule Holdco.Notifications.NotificationChannel do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_providers ~w(slack telegram email in_app)

  schema "notification_channels" do
    field :provider, :string
    field :is_active, :boolean, default: true
    field :config, :map, default: %{}
    field :event_types, {:array, :string}, default: []
    field :notes, :string
    belongs_to :user, Holdco.Accounts.User
    has_many :deliveries, Holdco.Notifications.NotificationDelivery, foreign_key: :channel_id
    timestamps(type: :utc_datetime)
  end

  def changeset(channel, attrs) do
    channel
    |> cast(attrs, [:user_id, :provider, :is_active, :config, :event_types, :notes])
    |> validate_required([:user_id, :provider])
    |> validate_inclusion(:provider, @valid_providers)
    |> foreign_key_constraint(:user_id)
  end

  def valid_providers, do: @valid_providers
end
