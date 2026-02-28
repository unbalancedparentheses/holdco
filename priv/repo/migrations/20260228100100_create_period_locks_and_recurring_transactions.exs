defmodule Holdco.Repo.Migrations.CreatePeriodLocksAndRecurringTransactions do
  use Ecto.Migration

  def change do
    create table(:period_locks) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :period_start, :date, null: false
      add :period_end, :date, null: false
      add :period_type, :string, null: false
      add :status, :string, null: false, default: "locked"
      add :locked_at, :utc_datetime
      add :locked_by_id, :id
      add :unlocked_at, :utc_datetime
      add :unlocked_by_id, :id
      add :unlock_reason, :text
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:period_locks, [:company_id])
    create index(:period_locks, [:status])
    create index(:period_locks, [:period_start, :period_end])

    create table(:recurring_transactions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :description, :string, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :frequency, :string, null: false
      add :start_date, :string, null: false
      add :end_date, :string
      add :next_run_date, :string, null: false
      add :last_run_date, :string
      add :is_active, :boolean, default: true
      add :transaction_type, :string
      add :counterparty, :string
      add :debit_account_id, references(:accounts, on_delete: :nilify_all)
      add :credit_account_id, references(:accounts, on_delete: :nilify_all)
      add :auto_post, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:recurring_transactions, [:company_id])
    create index(:recurring_transactions, [:is_active])
    create index(:recurring_transactions, [:next_run_date])
  end
end
