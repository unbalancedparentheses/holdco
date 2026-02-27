defmodule Holdco.Governance.JointVenture do
  use Ecto.Schema
  import Ecto.Changeset

  schema "joint_ventures" do
    field :partner, :string
    field :name, :string
    field :ownership_pct, :decimal, default: 50
    field :formation_date, :string
    field :status, :string, default: "active"
    field :total_value, :decimal
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(joint_venture, attrs) do
    joint_venture
    |> cast(attrs, [
      :company_id,
      :partner,
      :name,
      :ownership_pct,
      :formation_date,
      :status,
      :total_value,
      :currency,
      :notes
    ])
    |> validate_required([:company_id, :partner, :name])
  end
end
