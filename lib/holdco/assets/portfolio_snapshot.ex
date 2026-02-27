defmodule Holdco.Assets.PortfolioSnapshot do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "portfolio_snapshots" do
    field :date, :string
    field :liquid, :decimal, default: 0
    field :marketable, :decimal, default: 0
    field :illiquid, :decimal, default: 0
    field :liabilities, :decimal, default: 0
    field :nav, :decimal, default: 0
    field :currency, :string, default: "USD"

    timestamps(type: :utc_datetime)
  end

  def changeset(portfolio_snapshot, attrs) do
    portfolio_snapshot
    |> cast(attrs, [:date, :liquid, :marketable, :illiquid, :liabilities, :nav, :currency])
    |> validate_required([:date])
    |> validate_date_format(:date)
  end
end
