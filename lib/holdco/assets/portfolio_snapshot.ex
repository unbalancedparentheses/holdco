defmodule Holdco.Assets.PortfolioSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "portfolio_snapshots" do
    field :date, :string
    field :liquid, :float, default: 0.0
    field :marketable, :float, default: 0.0
    field :illiquid, :float, default: 0.0
    field :liabilities, :float, default: 0.0
    field :nav, :float, default: 0.0
    field :currency, :string, default: "USD"

    timestamps(type: :utc_datetime)
  end

  def changeset(portfolio_snapshot, attrs) do
    portfolio_snapshot
    |> cast(attrs, [:date, :liquid, :marketable, :illiquid, :liabilities, :nav, :currency])
    |> validate_required([:date])
  end
end
