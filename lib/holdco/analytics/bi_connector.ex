defmodule Holdco.Analytics.BiConnector do
  use Ecto.Schema
  import Ecto.Changeset

  @connector_types ~w(power_bi tableau looker metabase custom)
  @refresh_frequencies ~w(manual hourly daily weekly)
  @sync_statuses ~w(idle syncing error completed)

  schema "bi_connectors" do
    field :name, :string
    field :connector_type, :string
    field :connection_string_encrypted, :string
    field :api_key_encrypted, :string
    field :dataset_name, :string
    field :refresh_frequency, :string, default: "manual"
    field :last_sync_at, :utc_datetime
    field :sync_status, :string, default: "idle"
    field :tables_included, {:array, :string}, default: []
    field :row_limit, :integer
    field :format, :string, default: "json"
    field :is_active, :boolean, default: true
    field :error_log, :string
    field :notes, :string

    has_many :export_logs, Holdco.Analytics.BiExportLog, foreign_key: :connector_id

    timestamps(type: :utc_datetime)
  end

  def changeset(bi_connector, attrs) do
    bi_connector
    |> cast(attrs, [
      :name, :connector_type, :connection_string_encrypted, :api_key_encrypted,
      :dataset_name, :refresh_frequency, :last_sync_at, :sync_status,
      :tables_included, :row_limit, :format, :is_active, :error_log, :notes
    ])
    |> validate_required([:name, :connector_type])
    |> validate_inclusion(:connector_type, @connector_types)
    |> validate_inclusion(:refresh_frequency, @refresh_frequencies)
    |> validate_inclusion(:sync_status, @sync_statuses)
  end

  def connector_types, do: @connector_types
  def refresh_frequencies, do: @refresh_frequencies
  def sync_statuses, do: @sync_statuses
end
