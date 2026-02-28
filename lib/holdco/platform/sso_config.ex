defmodule Holdco.Platform.SsoConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sso_configs" do
    field :name, :string
    field :provider_type, :string
    field :entity_id, :string
    field :sso_url, :string
    field :slo_url, :string
    field :certificate, :string
    field :metadata_url, :string
    field :client_id, :string
    field :client_secret_encrypted, :string
    field :scopes, :string
    field :attribute_mapping, :map, default: %{}
    field :auto_provision_users, :boolean, default: false
    field :default_role, :string
    field :is_active, :boolean, default: true
    field :last_synced_at, :utc_datetime
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(sso_config, attrs) do
    sso_config
    |> cast(attrs, [
      :name,
      :provider_type,
      :entity_id,
      :sso_url,
      :slo_url,
      :certificate,
      :metadata_url,
      :client_id,
      :client_secret_encrypted,
      :scopes,
      :attribute_mapping,
      :auto_provision_users,
      :default_role,
      :is_active,
      :last_synced_at,
      :notes
    ])
    |> validate_required([:name, :provider_type])
    |> validate_inclusion(:provider_type, ~w(saml oidc oauth2))
  end
end
