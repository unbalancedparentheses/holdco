defmodule Holdco.Compliance.InsuranceClaim do
  use Ecto.Schema
  import Ecto.Changeset

  @claim_types ~w(property liability professional cyber directors_officers workers_comp other)
  @statuses ~w(filed under_review approved denied settled closed)

  schema "insurance_claims" do
    field :claim_number, :string
    field :incident_date, :date
    field :filing_date, :date
    field :claim_type, :string, default: "other"
    field :description, :string
    field :claimed_amount, :decimal
    field :settled_amount, :decimal
    field :deductible, :decimal
    field :status, :string, default: "filed"
    field :adjuster_name, :string
    field :adjuster_contact, :string
    field :settlement_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :insurance_policy, Holdco.Compliance.InsurancePolicy, foreign_key: :policy_id

    timestamps(type: :utc_datetime)
  end

  def changeset(insurance_claim, attrs) do
    insurance_claim
    |> cast(attrs, [
      :company_id,
      :policy_id,
      :claim_number,
      :incident_date,
      :filing_date,
      :claim_type,
      :description,
      :claimed_amount,
      :settled_amount,
      :deductible,
      :status,
      :adjuster_name,
      :adjuster_contact,
      :settlement_date,
      :notes
    ])
    |> validate_required([:company_id, :claim_number, :claim_type])
    |> validate_inclusion(:claim_type, @claim_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:claimed_amount, greater_than_or_equal_to: 0)
    |> validate_number(:settled_amount, greater_than_or_equal_to: 0)
    |> validate_number(:deductible, greater_than_or_equal_to: 0)
    |> unique_constraint(:claim_number)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:policy_id)
  end

  def claim_types, do: @claim_types
  def statuses, do: @statuses
end
