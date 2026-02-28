defmodule Holdco.Repo.Migrations.CreateDataDeletionRequests do
  use Ecto.Migration

  def change do
    create table(:data_deletion_requests) do
      add :requested_by_email, :string, null: false
      add :request_type, :string, null: false
      add :status, :string, default: "pending"
      add :data_categories, {:array, :string}, default: []
      add :reason, :text
      add :processed_by_id, :integer
      add :processed_at, :utc_datetime
      add :denial_reason, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:data_deletion_requests, [:status])
    create index(:data_deletion_requests, [:request_type])
  end
end
