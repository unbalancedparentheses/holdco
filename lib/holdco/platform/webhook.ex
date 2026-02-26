defmodule Holdco.Platform.Webhook do
  use Ecto.Schema
  import Ecto.Changeset

  schema "webhooks" do
    field :url, :string
    field :events, :string, default: "[]"
    field :is_active, :boolean, default: true
    field :secret, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(webhook, attrs) do
    webhook
    |> cast(attrs, [:url, :events, :is_active, :secret, :notes])
    |> validate_required([:url])
  end
end
