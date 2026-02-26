defmodule Holdco.Corporate.BeneficialOwner do
  use Ecto.Schema
  import Ecto.Changeset

  schema "beneficial_owners" do
    field :name, :string
    field :nationality, :string
    field :ownership_pct, :float, default: 0.0
    field :control_type, :string, default: "direct"
    field :verified, :boolean, default: false
    field :verified_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(beneficial_owner, attrs) do
    beneficial_owner
    |> cast(attrs, [
      :company_id,
      :name,
      :nationality,
      :ownership_pct,
      :control_type,
      :verified,
      :verified_date,
      :notes
    ])
    |> validate_required([:company_id, :name])
  end
end
