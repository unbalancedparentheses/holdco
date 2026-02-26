defmodule Holdco.Banking.Transaction do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :transaction_type, :string
    field :description, :string
    field :amount, :float
    field :currency, :string, default: "USD"
    field :counterparty, :string
    field :date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :asset_holding, Holdco.Assets.AssetHolding

    timestamps(type: :utc_datetime)
  end

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :company_id,
      :transaction_type,
      :description,
      :amount,
      :currency,
      :counterparty,
      :date,
      :asset_holding_id,
      :notes
    ])
    |> validate_required([:company_id, :transaction_type, :description, :amount, :date])
  end
end
