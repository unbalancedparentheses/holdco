defmodule Holdco.Analytics.Anomaly do
  use Ecto.Schema
  import Ecto.Changeset

  @entity_types ~w(transaction financial holding bank_account)
  @anomaly_types ~w(outlier duplicate unusual_amount unusual_frequency rapid_change)
  @severities ~w(low medium high critical)
  @statuses ~w(open investigating resolved false_positive)

  schema "anomalies" do
    field :entity_type, :string
    field :entity_id, :integer
    field :anomaly_type, :string
    field :severity, :string, default: "medium"
    field :description, :string
    field :detected_value, :decimal
    field :expected_range_low, :decimal
    field :expected_range_high, :decimal
    field :deviation_pct, :decimal
    field :status, :string, default: "open"
    field :resolved_at, :utc_datetime
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :resolved_by, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(anomaly, attrs) do
    anomaly
    |> cast(attrs, [
      :company_id, :entity_type, :entity_id, :anomaly_type, :severity,
      :description, :detected_value, :expected_range_low, :expected_range_high,
      :deviation_pct, :status, :resolved_at, :resolved_by_id, :notes
    ])
    |> validate_required([:entity_type, :anomaly_type])
    |> validate_inclusion(:entity_type, @entity_types)
    |> validate_inclusion(:anomaly_type, @anomaly_types)
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:status, @statuses)
  end

  def entity_types, do: @entity_types
  def anomaly_types, do: @anomaly_types
  def severities, do: @severities
  def statuses, do: @statuses
end
