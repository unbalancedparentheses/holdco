defmodule Holdco.Repo.Migrations.CreateMultiBookAccounting do
  use Ecto.Migration

  def change do
    create table(:accounting_books) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :book_type, :string, null: false
      add :base_currency, :string, default: "USD"
      add :is_primary, :boolean, default: false
      add :description, :text
      add :is_active, :boolean, default: true
      timestamps(type: :utc_datetime)
    end

    create table(:book_adjustments) do
      add :book_id, references(:accounting_books, on_delete: :delete_all), null: false
      add :journal_entry_id, references(:journal_entries, on_delete: :nilify_all)
      add :adjustment_type, :string, null: false
      add :debit_account_id, references(:accounts, on_delete: :nilify_all)
      add :credit_account_id, references(:accounts, on_delete: :nilify_all)
      add :amount, :decimal, null: false
      add :description, :text
      add :effective_date, :date, null: false
      timestamps(type: :utc_datetime)
    end

    create index(:accounting_books, [:company_id])
    create index(:accounting_books, [:book_type])
    create index(:book_adjustments, [:book_id])
    create index(:book_adjustments, [:journal_entry_id])
    create index(:book_adjustments, [:effective_date])
  end
end
