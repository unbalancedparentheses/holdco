defmodule Holdco.Repo.Migrations.AddApprovalVotes do
  use Ecto.Migration

  def change do
    alter table(:approval_requests) do
      add :required_approvals, :integer, default: 1
    end

    create table(:approval_votes) do
      add :approval_request_id, references(:approval_requests, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :decision, :string, null: false
      add :notes, :string
      timestamps(type: :utc_datetime)
    end

    create index(:approval_votes, [:approval_request_id])
    create unique_index(:approval_votes, [:approval_request_id, :user_id])
  end
end
