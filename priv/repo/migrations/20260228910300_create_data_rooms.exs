defmodule Holdco.Repo.Migrations.CreateDataRooms do
  use Ecto.Migration

  def change do
    create table(:data_rooms) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :description, :text
      add :access_level, :string, null: false, default: "restricted"
      add :status, :string, null: false, default: "active"
      add :created_by_id, references(:users, on_delete: :nilify_all)
      add :expires_at, :utc_datetime
      add :watermark_enabled, :boolean, default: true
      add :download_allowed, :boolean, default: true
      add :visitor_count, :integer, default: 0
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:data_rooms, [:company_id])
    create index(:data_rooms, [:status])
    create index(:data_rooms, [:access_level])

    create table(:data_room_documents) do
      add :data_room_id, references(:data_rooms, on_delete: :delete_all), null: false
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :section_name, :string
      add :sort_order, :integer, default: 0
      add :added_by_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:data_room_documents, [:data_room_id])
    create index(:data_room_documents, [:document_id])
  end
end
