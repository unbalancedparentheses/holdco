defmodule Holdco.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budgets" do
    field :period, :string
    field :category, :string
    field :budgeted, :decimal, default: 0
    field :actual, :decimal, default: 0
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [:company_id, :period, :category, :budgeted, :actual, :currency, :notes])
    |> validate_required([:company_id, :period, :category])
    |> validate_number(:budgeted, greater_than_or_equal_to: 0)
    |> validate_number(:actual, greater_than_or_equal_to: 0)
  end
end
