defmodule Holdco.Integrations.AccountingSyncConfig do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounting_sync_configs" do
    field :provider, :string
    field :external_id, :string, default: ""
    field :access_token, :string, default: ""
    field :refresh_token, :string, default: ""
    field :token_expires_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :last_sync_at, :utc_datetime
    field :sync_direction, :string, default: "both"
    field :notes, :string, default: ""

    belongs_to :company, Holdco.Corporate.Company
    has_many :sync_logs, Holdco.Integrations.AccountingSyncLog, foreign_key: :config_id

    timestamps(type: :utc_datetime)
  end

  def changeset(accounting_sync_config, attrs) do
    accounting_sync_config
    |> cast(attrs, [:company_id, :provider, :external_id, :access_token, :refresh_token,
                     :token_expires_at, :is_active, :last_sync_at, :sync_direction, :notes])
    |> validate_required([:company_id, :provider])
  end
end
