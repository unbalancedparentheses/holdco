defmodule Holdco.Integrations.Integration do
  use Ecto.Schema
  import Ecto.Changeset

  schema "integrations" do
    field :provider, :string
    field :realm_id, :string
    field :access_token, :string
    field :refresh_token, :string
    field :token_expires_at, :utc_datetime
    field :last_synced_at, :utc_datetime
    field :status, :string, default: "disconnected"
    field :metadata, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(integration, attrs) do
    integration
    |> cast(attrs, [
      :provider,
      :realm_id,
      :access_token,
      :refresh_token,
      :token_expires_at,
      :last_synced_at,
      :status,
      :metadata
    ])
    |> validate_required([:provider])
    |> unique_constraint(:provider)
  end
end
