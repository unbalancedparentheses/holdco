defmodule Holdco.Finance.Segment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "segments" do
    field :name, :string
    field :segment_type, :string, default: "business"
    field :description, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(segment, attrs) do
    segment
    |> cast(attrs, [:name, :segment_type, :description, :company_id])
    |> validate_required([:name])
    |> validate_inclusion(:segment_type, ~w(business geographic product))
  end
end
