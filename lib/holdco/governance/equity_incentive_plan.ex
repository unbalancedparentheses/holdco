defmodule Holdco.Governance.EquityIncentivePlan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "equity_incentive_plans" do
    field :plan_name, :string
    field :total_pool, :integer, default: 0
    field :vesting_schedule, :string
    field :board_approval_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :grants, Holdco.Governance.EquityGrant, foreign_key: :plan_id

    timestamps(type: :utc_datetime)
  end

  def changeset(equity_incentive_plan, attrs) do
    equity_incentive_plan
    |> cast(attrs, [:company_id, :plan_name, :total_pool, :vesting_schedule,
                     :board_approval_date, :notes])
    |> validate_required([:company_id, :plan_name])
  end
end
