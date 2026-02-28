defmodule Holdco.Repo.Migrations.CreateAirdrops do
  use Ecto.Migration

  def change do
    create table(:airdrops) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :event_type, :string, null: false, default: "airdrop"
      add :token_name, :string, null: false
      add :chain, :string, null: false, default: "ethereum"
      add :amount, :decimal
      add :value_at_receipt, :decimal
      add :current_value, :decimal
      add :currency, :string, default: "USD"
      add :wallet_address, :string
      add :received_date, :date
      add :claimed, :boolean, default: false
      add :claimed_date, :date
      add :eligible, :boolean, default: true
      add :snapshot_date, :date
      add :tax_treated, :boolean, default: false
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:airdrops, [:company_id])
    create index(:airdrops, [:event_type])
    create index(:airdrops, [:chain])
    create index(:airdrops, [:claimed])
  end
end
