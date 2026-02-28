defmodule Holdco.Analytics.LiquidityCoverage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "liquidity_coverages" do
    field :calculation_date, :date
    field :hqla_level1, :decimal, default: Decimal.new(0)
    field :hqla_level2a, :decimal, default: Decimal.new(0)
    field :hqla_level2b, :decimal, default: Decimal.new(0)
    field :total_hqla, :decimal, default: Decimal.new(0)
    field :net_cash_outflows_30d, :decimal, default: Decimal.new(0)
    field :lcr_ratio, :decimal, default: Decimal.new(0)
    field :status, :string, default: "adequate"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(liquidity_coverage, attrs) do
    liquidity_coverage
    |> cast(attrs, [
      :calculation_date,
      :hqla_level1,
      :hqla_level2a,
      :hqla_level2b,
      :total_hqla,
      :net_cash_outflows_30d,
      :lcr_ratio,
      :status,
      :notes,
      :company_id
    ])
    |> validate_required([:calculation_date])
    |> validate_inclusion(:status, ~w(adequate warning critical))
  end
end
