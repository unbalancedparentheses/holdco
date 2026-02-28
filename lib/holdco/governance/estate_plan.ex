defmodule Holdco.Governance.EstatePlan do
  use Ecto.Schema
  import Ecto.Changeset

  @plan_types ~w(will trust power_of_attorney healthcare_directive beneficiary_designation buy_sell_agreement)
  @statuses ~w(draft executed filed superseded revoked)

  schema "estate_plans" do
    field :plan_name, :string
    field :plan_type, :string
    field :principal_name, :string
    field :attorney_name, :string
    field :executor_name, :string
    field :status, :string, default: "draft"
    field :effective_date, :date
    field :last_reviewed_date, :date
    field :next_review_date, :date
    field :key_provisions, :string
    field :asset_summary, :map, default: %{}
    field :estimated_estate_value, :decimal
    field :currency, :string, default: "USD"
    field :tax_implications, :string
    field :notes, :string

    belongs_to :family_charter, Holdco.Governance.FamilyCharter

    timestamps(type: :utc_datetime)
  end

  def changeset(estate_plan, attrs) do
    estate_plan
    |> cast(attrs, [
      :family_charter_id,
      :plan_name,
      :plan_type,
      :principal_name,
      :attorney_name,
      :executor_name,
      :status,
      :effective_date,
      :last_reviewed_date,
      :next_review_date,
      :key_provisions,
      :asset_summary,
      :estimated_estate_value,
      :currency,
      :tax_implications,
      :notes
    ])
    |> validate_required([:plan_name, :plan_type, :principal_name])
    |> validate_inclusion(:plan_type, @plan_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:estimated_estate_value, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:family_charter_id)
  end

  def plan_types, do: @plan_types
  def statuses, do: @statuses
end
