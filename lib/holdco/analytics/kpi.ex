defmodule Holdco.Analytics.Kpi do
  use Ecto.Schema
  import Ecto.Changeset

  schema "kpis" do
    field :name, :string
    field :metric_type, :string, default: "currency"
    field :target_value, :float
    field :threshold_value, :float
    field :unit, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :snapshots, Holdco.Analytics.KpiSnapshot

    timestamps(type: :utc_datetime)
  end

  def changeset(kpi, attrs) do
    kpi
    |> cast(attrs, [:name, :metric_type, :target_value, :threshold_value, :unit, :company_id])
    |> validate_required([:name])
    |> validate_inclusion(:metric_type, ~w(currency percentage count ratio))
  end
end
