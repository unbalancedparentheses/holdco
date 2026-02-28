defmodule Holdco.Fund.WaterfallTier do
  use Ecto.Schema
  import Ecto.Changeset

  schema "waterfall_tiers" do
    field :tier_order, :integer
    field :name, :string
    field :description, :string
    field :tier_type, :string
    field :hurdle_rate, :decimal
    field :split_lp_pct, :decimal
    field :split_gp_pct, :decimal

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(tier, attrs) do
    tier
    |> cast(attrs, [:company_id, :tier_order, :name, :description, :tier_type, :hurdle_rate, :split_lp_pct, :split_gp_pct])
    |> validate_required([:company_id, :tier_order, :name])
    |> validate_inclusion(:tier_type, ~w(return_of_capital preferred_return catch_up carried_interest residual))
    |> foreign_key_constraint(:company_id)
  end
end
