defmodule Holdco.Repo.Migrations.CreateTrustTransactions do
  use Ecto.Migration

  def change do
    create table(:trust_transactions) do
      add :trust_account_id, references(:trust_accounts, on_delete: :delete_all), null: false
      add :transaction_type, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :description, :string
      add :counterparty, :string
      add :transaction_date, :date, null: false
      add :category, :string, default: "principal"
      add :approved_by, :string
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:trust_transactions, [:trust_account_id])
    create index(:trust_transactions, [:transaction_type])
    create index(:trust_transactions, [:transaction_date])
  end
end
