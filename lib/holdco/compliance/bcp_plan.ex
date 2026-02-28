defmodule Holdco.Compliance.BcpPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @plan_types ~w(disaster_recovery business_continuity pandemic cyber_incident financial_crisis)
  @statuses ~w(draft approved active under_review retired)
  @test_results ~w(passed partial failed not_tested)

  schema "bcp_plans" do
    field :plan_name, :string
    field :plan_type, :string, default: "business_continuity"
    field :version, :string
    field :status, :string, default: "draft"
    field :approved_by, :string
    field :approved_date, :date
    field :last_tested_date, :date
    field :next_test_date, :date
    field :test_result, :string, default: "not_tested"
    field :rto_hours, :integer
    field :rpo_hours, :integer
    field :key_contacts, {:array, :map}, default: []
    field :critical_systems, {:array, :string}, default: []
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(bcp_plan, attrs) do
    bcp_plan
    |> cast(attrs, [
      :company_id,
      :plan_name,
      :plan_type,
      :version,
      :status,
      :approved_by,
      :approved_date,
      :last_tested_date,
      :next_test_date,
      :test_result,
      :rto_hours,
      :rpo_hours,
      :key_contacts,
      :critical_systems,
      :notes
    ])
    |> validate_required([:company_id, :plan_name, :plan_type])
    |> validate_inclusion(:plan_type, @plan_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_inclusion(:test_result, @test_results)
    |> foreign_key_constraint(:company_id)
  end

  def plan_types, do: @plan_types
  def statuses, do: @statuses
  def test_results, do: @test_results
end
