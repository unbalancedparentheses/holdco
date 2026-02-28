defmodule Holdco.Governance.FamilyCharter do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses ~w(draft active under_review archived)

  schema "family_charters" do
    field :family_name, :string
    field :version, :string
    field :status, :string, default: "draft"
    field :mission_statement, :string
    field :values, {:array, :string}, default: []
    field :decision_making_process, :string
    field :succession_plan, :string
    field :education_policy, :string
    field :employment_policy, :string
    field :distribution_policy, :string
    field :conflict_resolution, :string
    field :meeting_schedule, :string
    field :next_review_date, :date
    field :approved_by, {:array, :string}, default: []
    field :approved_date, :date
    field :notes, :string

    has_many :family_members, Holdco.Governance.FamilyMember

    timestamps(type: :utc_datetime)
  end

  def changeset(family_charter, attrs) do
    family_charter
    |> cast(attrs, [
      :family_name,
      :version,
      :status,
      :mission_statement,
      :values,
      :decision_making_process,
      :succession_plan,
      :education_policy,
      :employment_policy,
      :distribution_policy,
      :conflict_resolution,
      :meeting_schedule,
      :next_review_date,
      :approved_by,
      :approved_date,
      :notes
    ])
    |> validate_required([:family_name, :version])
    |> validate_inclusion(:status, @statuses)
  end

  def statuses, do: @statuses
end
