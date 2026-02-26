defmodule Holdco.Analytics.KpiSnapshot do
  use Ecto.Schema
  import Ecto.Changeset

  schema "kpi_snapshots" do
    field :current_value, :float
    field :trend, :string
    field :date, :string

    belongs_to :kpi, Holdco.Analytics.Kpi

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:current_value, :trend, :date, :kpi_id])
    |> validate_required([:kpi_id])
  end
end
