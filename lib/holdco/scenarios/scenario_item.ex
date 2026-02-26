defmodule Holdco.Scenarios.ScenarioItem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scenario_items" do
    field :name, :string
    field :item_type, :string, default: "revenue"
    field :amount, :float, default: 0.0
    field :currency, :string, default: "USD"
    field :growth_rate, :float, default: 0.0
    field :growth_type, :string, default: "linear"
    field :recurrence, :string, default: "monthly"
    field :probability, :float, default: 1.0
    field :start_date, :string
    field :end_date, :string
    field :notes, :string

    belongs_to :scenario, Holdco.Scenarios.Scenario

    timestamps(type: :utc_datetime)
  end

  def changeset(scenario_item, attrs) do
    scenario_item
    |> cast(attrs, [:scenario_id, :name, :item_type, :amount, :currency, :growth_rate,
                     :growth_type, :recurrence, :probability, :start_date, :end_date, :notes])
    |> validate_required([:scenario_id, :name])
  end
end
