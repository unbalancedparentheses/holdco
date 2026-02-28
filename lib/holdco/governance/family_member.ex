defmodule Holdco.Governance.FamilyMember do
  use Ecto.Schema
  import Ecto.Changeset

  @roles ~w(member trustee advisor director officer beneficiary)
  @employment_statuses ~w(not_employed employed advisory)

  schema "family_members" do
    field :full_name, :string
    field :relationship, :string
    field :generation, :integer
    field :date_of_birth, :date
    field :role_in_family_office, :string, default: "member"
    field :voting_rights, :boolean, default: false
    field :board_eligible, :boolean, default: false
    field :employment_status, :string, default: "not_employed"
    field :branch, :string
    field :contact_email, :string
    field :notes, :string

    belongs_to :family_charter, Holdco.Governance.FamilyCharter

    timestamps(type: :utc_datetime)
  end

  def changeset(family_member, attrs) do
    family_member
    |> cast(attrs, [
      :family_charter_id,
      :full_name,
      :relationship,
      :generation,
      :date_of_birth,
      :role_in_family_office,
      :voting_rights,
      :board_eligible,
      :employment_status,
      :branch,
      :contact_email,
      :notes
    ])
    |> validate_required([:family_charter_id, :full_name, :relationship])
    |> validate_inclusion(:role_in_family_office, @roles)
    |> validate_inclusion(:employment_status, @employment_statuses)
    |> validate_number(:generation, greater_than: 0)
    |> foreign_key_constraint(:family_charter_id)
  end

  def roles, do: @roles
  def employment_statuses, do: @employment_statuses
end
