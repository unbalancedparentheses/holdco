defmodule Holdco.Fund.DividendPolicy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dividend_policies" do
    field :name, :string
    field :policy_type, :string
    field :target_payout_ratio, :decimal
    field :fixed_amount, :decimal
    field :growth_rate, :decimal
    field :frequency, :string, default: "quarterly"
    field :min_retained_earnings, :decimal
    field :max_payout_ratio, :decimal
    field :is_active, :boolean, default: true
    field :last_dividend_date, :date
    field :next_dividend_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @required_fields [:company_id, :name, :policy_type]
  @optional_fields [
    :target_payout_ratio,
    :fixed_amount,
    :growth_rate,
    :frequency,
    :min_retained_earnings,
    :max_payout_ratio,
    :is_active,
    :last_dividend_date,
    :next_dividend_date,
    :notes
  ]

  @policy_types ~w(fixed_amount payout_ratio residual stable_growth)
  @frequencies ~w(monthly quarterly semi_annual annual)

  def changeset(policy, attrs) do
    policy
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:policy_type, @policy_types)
    |> validate_inclusion(:frequency, @frequencies)
    |> validate_number(:target_payout_ratio, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:fixed_amount, greater_than_or_equal_to: 0)
    |> validate_number(:growth_rate, greater_than_or_equal_to: 0)
    |> validate_number(:max_payout_ratio, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:min_retained_earnings, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end
end
