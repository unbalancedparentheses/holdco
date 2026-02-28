defmodule Holdco.Repo.Migrations.CreateRegisterEntries do
  use Ecto.Migration

  def change do
    create table(:register_entries) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :register_type, :string, null: false
      add :entry_date, :string, null: false
      add :person_name, :string
      add :role_or_description, :string
      add :shares_held, :decimal
      add :share_class, :string
      add :appointment_date, :string
      add :cessation_date, :string
      add :status, :string, null: false, default: "current"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:register_entries, [:company_id])
    create index(:register_entries, [:register_type])
    create index(:register_entries, [:status])
    create index(:register_entries, [:company_id, :register_type])
  end
end
