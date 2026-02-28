defmodule Holdco.Fund.FundNav do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fund_navs" do
    field :nav_date, :date
    field :total_assets, :decimal
    field :total_liabilities, :decimal
    field :net_asset_value, :decimal
    field :nav_per_unit, :decimal
    field :units_outstanding, :decimal
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(fund_nav, attrs) do
    fund_nav
    |> cast(attrs, [
      :company_id,
      :nav_date,
      :total_assets,
      :total_liabilities,
      :net_asset_value,
      :nav_per_unit,
      :units_outstanding,
      :currency,
      :notes
    ])
    |> validate_required([:company_id, :nav_date])
    |> unique_constraint([:company_id, :nav_date])
    |> foreign_key_constraint(:company_id)
  end
end
