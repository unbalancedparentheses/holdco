defmodule Holdco.Governance.EthicsReport do
  use Ecto.Schema
  import Ecto.Changeset

  @report_types ~w(whistleblower ethics_violation harassment fraud conflict_of_interest data_breach other)
  @reporter_types ~w(anonymous named_internal named_external)
  @severities ~w(low medium high critical)
  @statuses ~w(received under_investigation escalated resolved dismissed)

  schema "ethics_reports" do
    field :report_type, :string, default: "whistleblower"
    field :reporter_type, :string, default: "anonymous"
    field :reporter_name, :string
    field :severity, :string, default: "medium"
    field :description, :string
    field :involved_parties, :string
    field :status, :string, default: "received"
    field :assigned_investigator, :string
    field :investigation_notes, :string
    field :resolution, :string
    field :reported_date, :date
    field :resolved_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(ethics_report, attrs) do
    ethics_report
    |> cast(attrs, [
      :company_id,
      :report_type,
      :reporter_type,
      :reporter_name,
      :severity,
      :description,
      :involved_parties,
      :status,
      :assigned_investigator,
      :investigation_notes,
      :resolution,
      :reported_date,
      :resolved_date,
      :notes
    ])
    |> validate_required([:company_id, :report_type, :reporter_type, :severity, :description, :reported_date])
    |> validate_inclusion(:report_type, @report_types)
    |> validate_inclusion(:reporter_type, @reporter_types)
    |> validate_inclusion(:severity, @severities)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def report_types, do: @report_types
  def reporter_types, do: @reporter_types
  def severities, do: @severities
  def statuses, do: @statuses
end
