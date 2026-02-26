defmodule Holdco.Finance.Dividend do
  use Ecto.Schema
  import Ecto.Changeset

  schema "dividends" do
    field :amount, :float
    field :currency, :string, default: "USD"
    field :date, :string
    field :recipient, :string
    field :dividend_type, :string, default: "regular"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(dividend, attrs) do
    dividend
    |> cast(attrs, [:company_id, :amount, :currency, :date, :recipient, :dividend_type, :notes])
    |> validate_required([:company_id, :amount, :date])
  end
end
