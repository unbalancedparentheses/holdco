defmodule Holdco.Governance.SuccessionPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @timelines ~w(immediate short_term long_term)
  @statuses ~w(active triggered completed archived)

  schema "succession_plans" do
    field :position_title, :string
    field :current_holder, :string
    field :successor_candidates, {:array, :map}, default: []
    field :timeline, :string, default: "long_term"
    field :status, :string, default: "active"
    field :trigger_events, {:array, :string}, default: []
    field :last_reviewed_date, :date
    field :next_review_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(succession_plan, attrs) do
    succession_plan
    |> cast(attrs, [
      :company_id,
      :position_title,
      :current_holder,
      :successor_candidates,
      :timeline,
      :status,
      :trigger_events,
      :last_reviewed_date,
      :next_review_date,
      :notes
    ])
    |> validate_required([:company_id, :position_title, :current_holder])
    |> validate_inclusion(:timeline, @timelines)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def timelines, do: @timelines
  def statuses, do: @statuses
end
