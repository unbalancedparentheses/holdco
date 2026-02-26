defmodule Holdco.Assets.CryptoWallet do
  use Ecto.Schema
  import Ecto.Changeset

  schema "crypto_wallets" do
    field :wallet_address, :string
    field :blockchain, :string, default: "ethereum"
    field :wallet_type, :string, default: "hot"
    field :notes, :string

    belongs_to :holding, Holdco.Assets.AssetHolding

    timestamps(type: :utc_datetime)
  end

  def changeset(crypto_wallet, attrs) do
    crypto_wallet
    |> cast(attrs, [:holding_id, :wallet_address, :blockchain, :wallet_type, :notes])
    |> validate_required([:holding_id, :wallet_address])
  end
end
