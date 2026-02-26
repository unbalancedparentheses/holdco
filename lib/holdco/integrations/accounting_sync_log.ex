defmodule Holdco.Integrations.AccountingSyncLog do
  use Ecto.Schema
  import Ecto.Changeset

  schema "accounting_sync_logs" do
    field :status, :string, default: "running"
    field :records_synced, :integer, default: 0
    field :error_message, :string, default: ""
    field :completed_at, :utc_datetime

    belongs_to :config, Holdco.Integrations.AccountingSyncConfig

    timestamps(type: :utc_datetime)
  end

  def changeset(accounting_sync_log, attrs) do
    accounting_sync_log
    |> cast(attrs, [:config_id, :status, :records_synced, :error_message, :completed_at])
    |> validate_required([:config_id])
  end
end
