defmodule Holdco.Assets.RealEstateProperty do
  use Ecto.Schema
  import Ecto.Changeset

  schema "real_estate_properties" do
    field :name, :string
    field :address, :string
    field :property_type, :string, default: "commercial"
    field :purchase_date, :string
    field :purchase_price, :decimal
    field :current_valuation, :decimal
    field :rental_income_annual, :decimal
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(real_estate_property, attrs) do
    real_estate_property
    |> cast(attrs, [
      :company_id,
      :name,
      :address,
      :property_type,
      :purchase_date,
      :purchase_price,
      :current_valuation,
      :rental_income_annual,
      :currency,
      :notes
    ])
    |> validate_required([:company_id, :name])
  end
end
