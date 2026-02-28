defmodule Holdco.Compliance.Litigation do
  use Ecto.Schema
  import Ecto.Changeset

  @case_types ~w(civil criminal regulatory arbitration mediation administrative)
  @party_roles ~w(plaintiff defendant respondent petitioner)
  @statuses ~w(pre_filing active discovery trial appeal settled dismissed closed)

  schema "litigations" do
    field :case_name, :string
    field :case_number, :string
    field :court_or_tribunal, :string
    field :jurisdiction, :string
    field :case_type, :string, default: "civil"
    field :party_role, :string, default: "defendant"
    field :opposing_party, :string
    field :filing_date, :date
    field :status, :string, default: "active"
    field :estimated_exposure, :decimal
    field :actual_outcome_amount, :decimal
    field :currency, :string, default: "USD"
    field :lead_counsel, :string
    field :next_hearing_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(litigation, attrs) do
    litigation
    |> cast(attrs, [
      :company_id,
      :case_name,
      :case_number,
      :court_or_tribunal,
      :jurisdiction,
      :case_type,
      :party_role,
      :opposing_party,
      :filing_date,
      :status,
      :estimated_exposure,
      :actual_outcome_amount,
      :currency,
      :lead_counsel,
      :next_hearing_date,
      :notes
    ])
    |> validate_required([:company_id, :case_name, :case_type, :party_role])
    |> validate_inclusion(:case_type, @case_types)
    |> validate_inclusion(:party_role, @party_roles)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:estimated_exposure, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def case_types, do: @case_types
  def party_roles, do: @party_roles
  def statuses, do: @statuses
end
