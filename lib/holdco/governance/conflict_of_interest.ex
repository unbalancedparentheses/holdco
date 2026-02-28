defmodule Holdco.Governance.ConflictOfInterest do
  use Ecto.Schema
  import Ecto.Changeset

  @declarant_roles ~w(director officer employee advisor)
  @conflict_types ~w(financial personal professional organizational)
  @statuses ~w(declared under_review approved mitigated ongoing resolved)

  schema "conflicts_of_interest" do
    field :declarant_name, :string
    field :declarant_role, :string
    field :conflict_type, :string
    field :description, :string
    field :parties_involved, :string
    field :potential_impact, :string
    field :declared_date, :date
    field :review_date, :date
    field :status, :string, default: "declared"
    field :mitigation_plan, :string
    field :reviewer_name, :string
    field :review_notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(coi, attrs) do
    coi
    |> cast(attrs, [
      :company_id,
      :declarant_name,
      :declarant_role,
      :conflict_type,
      :description,
      :parties_involved,
      :potential_impact,
      :declared_date,
      :review_date,
      :status,
      :mitigation_plan,
      :reviewer_name,
      :review_notes
    ])
    |> validate_required([:company_id, :declarant_name, :declarant_role, :conflict_type, :description, :declared_date])
    |> validate_inclusion(:declarant_role, @declarant_roles)
    |> validate_inclusion(:conflict_type, @conflict_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def declarant_roles, do: @declarant_roles
  def conflict_types, do: @conflict_types
  def statuses, do: @statuses
end
