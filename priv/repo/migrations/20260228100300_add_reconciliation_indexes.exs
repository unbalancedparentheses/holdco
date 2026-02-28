defmodule Holdco.Repo.Migrations.AddReconciliationIndexes do
  use Ecto.Migration

  def change do
    create unique_index(:bank_feed_transactions, [:feed_config_id, :external_id])
    create index(:bank_feed_transactions, [:is_matched])
    create index(:bank_feed_transactions, [:matched_transaction_id])
  end
end
