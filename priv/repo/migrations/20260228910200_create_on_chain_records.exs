defmodule Holdco.Repo.Migrations.CreateOnChainRecords do
  use Ecto.Migration

  def change do
    create table(:on_chain_records) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :chain, :string, null: false, default: "ethereum"
      add :tx_hash, :string, null: false
      add :block_number, :integer
      add :from_address, :string
      add :to_address, :string
      add :amount, :decimal
      add :currency, :string, default: "USD"
      add :verified_at, :utc_datetime
      add :verification_status, :string, null: false, default: "pending"
      add :matched_transaction_id, references(:transactions, on_delete: :nilify_all)
      add :gas_fee, :decimal
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:on_chain_records, [:company_id])
    create index(:on_chain_records, [:chain])
    create index(:on_chain_records, [:verification_status])
    create unique_index(:on_chain_records, [:tx_hash])
  end
end
