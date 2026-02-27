defmodule Holdco.Repo.Migrations.CreateContactInteractions do
  use Ecto.Migration

  def change do
    create table(:contact_interactions) do
      add :contact_id, references(:contacts, on_delete: :delete_all), null: false
      add :interaction_type, :string, null: false
      add :summary, :text, null: false
      add :date, :string
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:contact_interactions, [:contact_id])
  end
end
