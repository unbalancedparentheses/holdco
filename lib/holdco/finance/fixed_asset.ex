defmodule Holdco.Finance.FixedAsset do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fixed_assets" do
    field :name, :string
    field :purchase_date, :string
    field :purchase_price, :decimal
    field :useful_life_months, :integer
    field :salvage_value, :decimal, default: 0
    field :depreciation_method, :string, default: "straight_line"
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :account, Holdco.Finance.Account

    timestamps(type: :utc_datetime)
  end

  def changeset(fixed_asset, attrs) do
    fixed_asset
    |> cast(attrs, [
      :name, :purchase_date, :purchase_price, :useful_life_months,
      :salvage_value, :depreciation_method, :currency, :notes,
      :company_id, :account_id
    ])
    |> validate_required([:name, :company_id])
    |> validate_inclusion(:depreciation_method, ~w(straight_line declining_balance))
  end
end
