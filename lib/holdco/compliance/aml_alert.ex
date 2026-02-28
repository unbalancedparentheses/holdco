defmodule Holdco.Compliance.AmlAlert do
  use Ecto.Schema
  import Ecto.Changeset

  @alert_types ~w(large_transaction structuring velocity geographic_risk pattern_match pep_related)
  @severities ~w(low medium high critical)
  @statuses ~w(open investigating escalated filed_sar dismissed)

  schema "aml_alerts" do
    field :transaction_id, :string
    field :alert_type, :string, default: "large_transaction"
    field :severity, :string, default: "medium"
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :description, :string
    field :rule_triggered, :string
    field :status, :string, default: "open"
    field :assigned_to, :string
    field :resolution_notes, :string
    field :resolved_at, :utc_datetime

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(alert, attrs) do
    alert
    |> cast(attrs, [
      :company_id,
      :transaction_id,
      :alert_type,
      :severity,
      :amount,
      :currency,
      :description,
      :rule_triggered,
      :status,
      :assigned_to,
      :resolution_notes,
      :resolved_at
    ])
    |> validate_required([:company_id, :alert_type, :severity])
    |> validate_inclusion(:alert_type, @alert_types)
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def alert_types, do: @alert_types
  def severities, do: @severities
  def statuses, do: @statuses
end
