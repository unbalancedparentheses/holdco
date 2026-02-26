defmodule Holdco.Compliance.RegulatoryLicense do
  use Ecto.Schema
  import Ecto.Changeset

  schema "regulatory_licenses" do
    field :license_type, :string
    field :issuing_authority, :string
    field :license_number, :string
    field :issue_date, :string
    field :expiry_date, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(regulatory_license, attrs) do
    regulatory_license
    |> cast(attrs, [:company_id, :license_type, :issuing_authority, :license_number,
                     :issue_date, :expiry_date, :status, :notes])
    |> validate_required([:company_id, :license_type, :issuing_authority])
  end
end
