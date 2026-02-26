defmodule Holdco.Compliance.EsgScore do
  use Ecto.Schema
  import Ecto.Changeset

  schema "esg_scores" do
    field :period, :string
    field :environmental_score, :float
    field :social_score, :float
    field :governance_score, :float
    field :overall_score, :float
    field :framework, :string, default: "custom"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(esg_score, attrs) do
    esg_score
    |> cast(attrs, [:company_id, :period, :environmental_score, :social_score,
                     :governance_score, :overall_score, :framework, :notes])
    |> validate_required([:company_id, :period])
  end
end
