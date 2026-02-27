defmodule Holdco.Finance.Financial do
  use Ecto.Schema
  import Ecto.Changeset

  schema "financials" do
    field :period, :string
    field :revenue, :decimal, default: 0
    field :expenses, :decimal, default: 0
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(financial, attrs) do
    financial
    |> cast(attrs, [:company_id, :period, :revenue, :expenses, :currency, :notes])
    |> validate_required([:company_id, :period])
    |> validate_number(:revenue, greater_than_or_equal_to: 0)
    |> validate_number(:expenses, greater_than_or_equal_to: 0)
  end
end
