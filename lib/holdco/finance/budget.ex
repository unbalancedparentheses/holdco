defmodule Holdco.Finance.Budget do
  use Ecto.Schema
  import Ecto.Changeset

  schema "budgets" do
    field :period, :string
    field :category, :string
    field :budgeted, :float, default: 0.0
    field :actual, :float, default: 0.0
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(budget, attrs) do
    budget
    |> cast(attrs, [:company_id, :period, :category, :budgeted, :actual, :currency, :notes])
    |> validate_required([:company_id, :period, :category])
  end
end
