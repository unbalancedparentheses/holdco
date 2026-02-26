defmodule Holdco.Assets.FundInvestment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fund_investments" do
    field :fund_name, :string
    field :fund_type, :string, default: "private_equity"
    field :commitment, :float, default: 0.0
    field :called, :float, default: 0.0
    field :distributed, :float, default: 0.0
    field :nav, :float, default: 0.0
    field :currency, :string, default: "USD"
    field :vintage_year, :integer
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(fund_investment, attrs) do
    fund_investment
    |> cast(attrs, [
      :company_id,
      :fund_name,
      :fund_type,
      :commitment,
      :called,
      :distributed,
      :nav,
      :currency,
      :vintage_year,
      :notes
    ])
    |> validate_required([:company_id, :fund_name])
  end
end
