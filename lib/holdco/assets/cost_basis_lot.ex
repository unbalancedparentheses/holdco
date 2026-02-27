defmodule Holdco.Assets.CostBasisLot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cost_basis_lots" do
    field :purchase_date, :string
    field :quantity, :decimal
    field :price_per_unit, :decimal
    field :fees, :decimal, default: 0
    field :currency, :string, default: "USD"
    field :sold_quantity, :decimal, default: 0
    field :sold_date, :string
    field :sold_price, :decimal
    field :notes, :string

    belongs_to :holding, Holdco.Assets.AssetHolding

    timestamps(type: :utc_datetime)
  end

  def changeset(cost_basis_lot, attrs) do
    cost_basis_lot
    |> cast(attrs, [
      :holding_id,
      :purchase_date,
      :quantity,
      :price_per_unit,
      :fees,
      :currency,
      :sold_quantity,
      :sold_date,
      :sold_price,
      :notes
    ])
    |> validate_required([:holding_id, :purchase_date, :quantity, :price_per_unit])
  end
end
