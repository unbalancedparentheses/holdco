defmodule Holdco.Governance.EquityGrant do
  use Ecto.Schema
  import Ecto.Changeset

  schema "equity_grants" do
    field :recipient, :string
    field :grant_type, :string, default: "options"
    field :quantity, :integer, default: 0
    field :strike_price, :float
    field :grant_date, :string
    field :vesting_start, :string
    field :cliff_months, :integer, default: 12
    field :vesting_months, :integer, default: 48
    field :exercised, :integer, default: 0
    field :notes, :string

    belongs_to :plan, Holdco.Governance.EquityIncentivePlan

    timestamps(type: :utc_datetime)
  end

  def changeset(equity_grant, attrs) do
    equity_grant
    |> cast(attrs, [:plan_id, :recipient, :grant_type, :quantity, :strike_price,
                     :grant_date, :vesting_start, :cliff_months, :vesting_months,
                     :exercised, :notes])
    |> validate_required([:plan_id, :recipient, :grant_date])
  end
end
