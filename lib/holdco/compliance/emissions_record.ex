defmodule Holdco.Compliance.EmissionsRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @scopes ~w(scope_1 scope_2 scope_3)
  @categories ~w(energy transport waste supply_chain other)
  @units ~w(tonnes_co2e kg_co2e mwh liters km)
  @verification_statuses ~w(unverified self_assessed third_party_verified)

  schema "emissions_records" do
    field :reporting_year, :integer
    field :scope, :string, default: "scope_1"
    field :category, :string, default: "energy"
    field :source_description, :string
    field :quantity, :decimal
    field :unit, :string, default: "tonnes_co2e"
    field :emission_factor, :decimal
    field :co2_equivalent, :decimal
    field :methodology, :string
    field :verification_status, :string, default: "unverified"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(emissions_record, attrs) do
    emissions_record
    |> cast(attrs, [
      :company_id,
      :reporting_year,
      :scope,
      :category,
      :source_description,
      :quantity,
      :unit,
      :emission_factor,
      :co2_equivalent,
      :methodology,
      :verification_status,
      :notes
    ])
    |> validate_required([:company_id, :reporting_year, :scope, :category])
    |> validate_inclusion(:scope, @scopes)
    |> validate_inclusion(:category, @categories)
    |> validate_inclusion(:unit, @units)
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> foreign_key_constraint(:company_id)
  end

  def scopes, do: @scopes
  def categories, do: @categories
  def units, do: @units
  def verification_statuses, do: @verification_statuses
end
