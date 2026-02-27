defmodule Holdco.Pricing.PriceHistory do
  use Ecto.Schema
  import Ecto.Changeset

  schema "price_history" do
    field :ticker, :string
    field :price, :decimal
    field :currency, :string, default: "USD"

    timestamps(type: :utc_datetime)
  end

  def changeset(price_history, attrs) do
    price_history
    |> cast(attrs, [:ticker, :price, :currency])
    |> validate_required([:ticker, :price])
  end
end
