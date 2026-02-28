defmodule Holdco.Repo.Migrations.CreateEntityLifecycles do
  use Ecto.Migration

  def change do
    create table(:entity_lifecycles) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :event_type, :string, null: false
      add :event_date, :string, null: false
      add :effective_date, :string
      add :jurisdiction, :string
      add :filing_reference, :string
      add :description, :string
      add :status, :string, null: false, default: "pending"
      add :documents, {:array, :string}, default: []
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:entity_lifecycles, [:company_id])
    create index(:entity_lifecycles, [:event_type])
    create index(:entity_lifecycles, [:status])
  end
end
