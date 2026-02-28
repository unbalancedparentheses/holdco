defmodule Holdco.Repo.Migrations.CreateActivityEvents do
  use Ecto.Migration

  def change do
    create table(:activity_events) do
      add :actor_id, references(:users, on_delete: :nilify_all)
      add :actor_email, :string
      add :action, :string, null: false
      add :entity_type, :string, null: false
      add :entity_id, :integer
      add :entity_name, :string
      add :context_module, :string
      add :metadata, :map, default: %{}
      add :company_id, references(:companies, on_delete: :nilify_all)
      add :ip_address, :string
      add :user_agent, :string

      timestamps(type: :utc_datetime)
    end

    create index(:activity_events, [:actor_id])
    create index(:activity_events, [:company_id])
    create index(:activity_events, [:action])
    create index(:activity_events, [:entity_type])
    create index(:activity_events, [:inserted_at])
  end
end
