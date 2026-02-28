defmodule Holdco.Compliance.KycRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @entity_types ~w(individual corporate trust fund)
  @risk_levels ~w(low medium high pep)
  @verification_statuses ~w(not_started documents_requested under_review verified rejected expired)
  @id_types ~w(passport national_id drivers_license corporate_registration)

  schema "kyc_records" do
    field :entity_name, :string
    field :entity_type, :string, default: "individual"
    field :risk_level, :string, default: "low"
    field :verification_status, :string, default: "not_started"
    field :id_type, :string
    field :id_number, :string
    field :id_expiry_date, :date
    field :country_of_residence, :string
    field :nationality, :string
    field :pep_status, :boolean, default: false
    field :sanctions_checked, :boolean, default: false
    field :last_review_date, :date
    field :next_review_date, :date
    field :reviewer_notes, :string
    field :documents, {:array, :string}, default: []

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(kyc_record, attrs) do
    kyc_record
    |> cast(attrs, [
      :company_id,
      :entity_name,
      :entity_type,
      :risk_level,
      :verification_status,
      :id_type,
      :id_number,
      :id_expiry_date,
      :country_of_residence,
      :nationality,
      :pep_status,
      :sanctions_checked,
      :last_review_date,
      :next_review_date,
      :reviewer_notes,
      :documents
    ])
    |> validate_required([:company_id, :entity_name, :entity_type])
    |> validate_inclusion(:entity_type, @entity_types)
    |> validate_inclusion(:risk_level, @risk_levels)
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> validate_inclusion(:id_type, @id_types ++ [nil])
    |> foreign_key_constraint(:company_id)
  end

  def entity_types, do: @entity_types
  def risk_levels, do: @risk_levels
  def verification_statuses, do: @verification_statuses
  def id_types, do: @id_types
end
