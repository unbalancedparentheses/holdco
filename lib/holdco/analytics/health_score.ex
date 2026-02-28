defmodule Holdco.Analytics.HealthScore do
  use Ecto.Schema
  import Ecto.Changeset

  @trends ~w(improving stable declining)

  schema "health_scores" do
    field :score_date, :date
    field :overall_score, :decimal
    field :liquidity_score, :decimal
    field :profitability_score, :decimal
    field :compliance_score, :decimal
    field :governance_score, :decimal
    field :risk_score, :decimal
    field :operational_score, :decimal
    field :components, :map, default: %{}
    field :trend, :string, default: "stable"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(score, attrs) do
    score
    |> cast(attrs, [
      :company_id, :score_date, :overall_score, :liquidity_score,
      :profitability_score, :compliance_score, :governance_score,
      :risk_score, :operational_score, :components, :trend, :notes
    ])
    |> validate_required([:company_id, :score_date, :overall_score])
    |> validate_inclusion(:trend, @trends)
    |> validate_number(:overall_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:liquidity_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:profitability_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:compliance_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:governance_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:risk_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_number(:operational_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:company_id)
  end

  def trends, do: @trends
end
