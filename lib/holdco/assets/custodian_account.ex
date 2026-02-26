defmodule Holdco.Assets.CustodianAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "custodian_accounts" do
    field :bank, :string
    field :account_number, :string
    field :account_type, :string
    field :authorized_persons, :string, default: "[]"

    belongs_to :asset_holding, Holdco.Assets.AssetHolding

    timestamps(type: :utc_datetime)
  end

  def changeset(custodian_account, attrs) do
    custodian_account
    |> cast(attrs, [:asset_holding_id, :bank, :account_number, :account_type, :authorized_persons])
    |> validate_required([:asset_holding_id, :bank])
  end
end
