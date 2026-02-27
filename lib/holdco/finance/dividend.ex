defmodule Holdco.Finance.Dividend do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "dividends" do
    field :amount, :decimal
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
    |> validate_number(:amount, greater_than: 0)
    |> validate_date_format(:date)
  end
end
