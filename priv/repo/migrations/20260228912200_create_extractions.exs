defmodule Holdco.Repo.Migrations.CreateExtractions do
  use Ecto.Migration

  def change do
    create table(:extractions) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :extraction_type, :string, default: "other", null: false
      add :status, :string, default: "pending", null: false
      add :extracted_data, :map, default: %{}
      add :confidence_score, :decimal
      add :model_used, :string
      add :processing_time_ms, :integer
      add :reviewed, :boolean, default: false
      add :reviewed_by_id, references(:users, on_delete: :nilify_all)
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:extractions, [:document_id])
    create index(:extractions, [:status])
    create index(:extractions, [:extraction_type])
    create index(:extractions, [:reviewed])
  end
end
