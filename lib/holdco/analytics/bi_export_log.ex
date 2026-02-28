defmodule Holdco.Analytics.BiExportLog do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(success partial failed)

  schema "bi_export_logs" do
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :rows_exported, :integer
    field :tables_exported, {:array, :string}, default: []
    field :status, :string
    field :error_message, :string
    field :file_size_bytes, :integer

    belongs_to :connector, Holdco.Analytics.BiConnector

    timestamps(type: :utc_datetime)
  end

  def changeset(bi_export_log, attrs) do
    bi_export_log
    |> cast(attrs, [
      :connector_id, :started_at, :completed_at, :rows_exported,
      :tables_exported, :status, :error_message, :file_size_bytes
    ])
    |> validate_required([:connector_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:connector_id)
  end

  def statuses, do: @statuses
end
