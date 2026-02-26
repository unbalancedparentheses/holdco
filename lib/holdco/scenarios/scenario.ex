defmodule Holdco.Scenarios.Scenario do
  use Ecto.Schema
  import Ecto.Changeset

  schema "scenarios" do
    field :name, :string
    field :description, :string
    field :base_period, :string
    field :projection_months, :integer, default: 12
    field :status, :string, default: "draft"

    belongs_to :company, Holdco.Corporate.Company
    has_many :items, Holdco.Scenarios.ScenarioItem

    timestamps(type: :utc_datetime)
  end

  def changeset(scenario, attrs) do
    scenario
    |> cast(attrs, [:name, :description, :company_id, :base_period, :projection_months, :status])
    |> validate_required([:name])
  end
end
