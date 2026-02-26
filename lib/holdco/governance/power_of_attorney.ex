defmodule Holdco.Governance.PowerOfAttorney do
  use Ecto.Schema
  import Ecto.Changeset

  schema "powers_of_attorney" do
    field :grantor, :string
    field :grantee, :string
    field :scope, :string
    field :start_date, :string
    field :end_date, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(power_of_attorney, attrs) do
    power_of_attorney
    |> cast(attrs, [:company_id, :grantor, :grantee, :scope, :start_date, :end_date,
                     :status, :notes])
    |> validate_required([:company_id, :grantor, :grantee])
  end
end
