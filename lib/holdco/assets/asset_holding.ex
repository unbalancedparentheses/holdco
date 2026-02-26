defmodule Holdco.Assets.AssetHolding do
  use Ecto.Schema
  import Ecto.Changeset

  schema "asset_holdings" do
    field :asset, :string
    field :ticker, :string
    field :quantity, :float
    field :unit, :string
    field :currency, :string, default: "USD"
    field :asset_type, :string, default: "other"

    belongs_to :company, Holdco.Corporate.Company
    has_one :custodian, Holdco.Assets.CustodianAccount, foreign_key: :asset_holding_id
    has_many :cost_basis_lots, Holdco.Assets.CostBasisLot, foreign_key: :holding_id
    has_many :crypto_wallets, Holdco.Assets.CryptoWallet, foreign_key: :holding_id

    timestamps(type: :utc_datetime)
  end

  def changeset(asset_holding, attrs) do
    asset_holding
    |> cast(attrs, [:company_id, :asset, :ticker, :quantity, :unit, :currency, :asset_type])
    |> validate_required([:company_id, :asset])
  end
end
