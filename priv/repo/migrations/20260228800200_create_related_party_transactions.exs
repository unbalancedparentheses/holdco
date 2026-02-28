defmodule Holdco.Repo.Migrations.CreateRelatedPartyTransactions do
  use Ecto.Migration

  def change do
    create table(:related_party_transactions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :related_party_name, :string, null: false
      add :relationship, :string, null: false
      add :transaction_type, :string, null: false
      add :transaction_date, :date, null: false
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :terms_description, :text
      add :arm_length_confirmation, :boolean, default: false
      add :board_approval_date, :date
      add :board_approval_reference, :string
      add :disclosure_required, :boolean, default: false
      add :disclosure_status, :string, default: "not_required"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:related_party_transactions, [:company_id])
    create index(:related_party_transactions, [:related_party_name])
    create index(:related_party_transactions, [:relationship])
    create index(:related_party_transactions, [:transaction_type])
  end
end
