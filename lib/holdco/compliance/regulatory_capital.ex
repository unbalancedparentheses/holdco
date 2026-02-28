defmodule Holdco.Compliance.RegulatoryCapital do
  use Ecto.Schema
  import Ecto.Changeset

  @frameworks ~w(basel_iii solvency_ii mifid_ii dodd_frank custom)
  @statuses ~w(compliant warning breach)

  schema "regulatory_capital" do
    field :reporting_date, :date
    field :framework, :string, default: "basel_iii"
    field :tier1_capital, :decimal
    field :tier2_capital, :decimal
    field :total_capital, :decimal
    field :risk_weighted_assets, :decimal
    field :capital_ratio, :decimal
    field :minimum_required_ratio, :decimal
    field :buffer_required, :decimal
    field :surplus_or_deficit, :decimal
    field :currency, :string, default: "USD"
    field :status, :string, default: "compliant"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(regulatory_capital, attrs) do
    regulatory_capital
    |> cast(attrs, [
      :company_id,
      :reporting_date,
      :framework,
      :tier1_capital,
      :tier2_capital,
      :total_capital,
      :risk_weighted_assets,
      :capital_ratio,
      :minimum_required_ratio,
      :buffer_required,
      :surplus_or_deficit,
      :currency,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :reporting_date, :framework])
    |> validate_inclusion(:framework, @frameworks)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def frameworks, do: @frameworks
  def statuses, do: @statuses
end
