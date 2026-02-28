defmodule Holdco.Corporate.LeiRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @registration_statuses ~w(pending issued lapsed retired)
  @entity_statuses ~w(active inactive)

  schema "lei_records" do
    field :lei_code, :string
    field :registration_status, :string, default: "pending"
    field :initial_registration_date, :date
    field :last_renewal_date, :date
    field :next_renewal_date, :date
    field :managing_lou, :string
    field :legal_name, :string
    field :jurisdiction, :string
    field :registration_authority, :string
    field :entity_status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(lei_record, attrs) do
    lei_record
    |> cast(attrs, [
      :company_id,
      :lei_code,
      :registration_status,
      :initial_registration_date,
      :last_renewal_date,
      :next_renewal_date,
      :managing_lou,
      :legal_name,
      :jurisdiction,
      :registration_authority,
      :entity_status,
      :notes
    ])
    |> validate_required([:company_id, :lei_code])
    |> validate_length(:lei_code, is: 20)
    |> validate_inclusion(:registration_status, @registration_statuses)
    |> validate_inclusion(:entity_status, @entity_statuses)
    |> unique_constraint(:lei_code)
    |> foreign_key_constraint(:company_id)
  end

  def registration_statuses, do: @registration_statuses
  def entity_statuses, do: @entity_statuses
end
