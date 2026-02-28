defmodule Holdco.Repo.Migrations.CreateFamilyMembers do
  use Ecto.Migration

  def change do
    create table(:family_members) do
      add :family_charter_id, references(:family_charters, on_delete: :delete_all), null: false
      add :full_name, :string, null: false
      add :relationship, :string, null: false
      add :generation, :integer
      add :date_of_birth, :date
      add :role_in_family_office, :string, default: "member"
      add :voting_rights, :boolean, default: false
      add :board_eligible, :boolean, default: false
      add :employment_status, :string, default: "not_employed"
      add :branch, :string
      add :contact_email, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:family_members, [:family_charter_id])
    create index(:family_members, [:generation])
    create index(:family_members, [:role_in_family_office])
  end
end
