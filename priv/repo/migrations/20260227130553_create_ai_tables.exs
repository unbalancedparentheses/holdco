defmodule Holdco.Repo.Migrations.CreateAiTables do
  use Ecto.Migration

  def change do
    create table(:ai_conversations) do
      add :title, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:ai_conversations, [:user_id])

    create table(:ai_messages) do
      add :role, :string, null: false
      add :content, :text, null: false
      add :conversation_id, references(:ai_conversations, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:ai_messages, [:conversation_id])
  end
end
