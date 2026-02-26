defmodule Holdco.Notifications.Notification do
  use Ecto.Schema
  import Ecto.Changeset

  schema "notifications" do
    field :title, :string
    field :body, :string
    field :type, :string, default: "info"
    field :read_at, :utc_datetime
    field :entity_type, :string
    field :entity_id, :integer
    field :action_url, :string
    belongs_to :user, Holdco.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(notification, attrs) do
    notification
    |> cast(attrs, [
      :user_id,
      :title,
      :body,
      :type,
      :entity_type,
      :entity_id,
      :action_url,
      :read_at
    ])
    |> validate_required([:user_id, :title])
  end
end
