defmodule Holdco.Repo.Migrations.CreateContactsAndProjects do
  use Ecto.Migration

  def change do
    create table(:contacts) do
      add :name, :string, null: false
      add :title, :string
      add :organization, :string
      add :email, :string
      add :phone, :string
      add :role_tag, :string
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:contact_companies) do
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :relationship, :string
      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_companies, [:contact_id, :company_id])

    create table(:projects) do
      add :name, :string, null: false
      add :status, :string, default: "planned"
      add :project_type, :string
      add :description, :text
      add :start_date, :date
      add :target_date, :date
      add :budget, :decimal
      add :currency, :string, default: "USD"
      add :notes, :text
      add :contact_id, references(:contacts, on_delete: :nilify_all)
      timestamps(type: :utc_datetime)
    end

    create table(:project_companies) do
      add :project_id, references(:projects, on_delete: :delete_all), null: false
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:project_companies, [:project_id, :company_id])
  end
end
