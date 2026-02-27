defmodule Holdco.Analytics.KpiSnapshot do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "kpi_snapshots" do
    field :current_value, :decimal
    field :trend, :string
    field :date, :string

    belongs_to :kpi, Holdco.Analytics.Kpi

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [:current_value, :trend, :date, :kpi_id])
    |> validate_required([:kpi_id])
    |> validate_date_format(:date)
  end
end
