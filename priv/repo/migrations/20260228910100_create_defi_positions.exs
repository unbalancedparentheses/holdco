defmodule Holdco.Repo.Migrations.CreateDefiPositions do
  use Ecto.Migration

  def change do
    create table(:defi_positions) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :protocol_name, :string, null: false
      add :chain, :string, null: false, default: "ethereum"
      add :position_type, :string, null: false, default: "lending"
      add :asset_pair, :string
      add :deposited_amount, :decimal
      add :current_value, :decimal
      add :unrealized_pnl, :decimal
      add :apy_current, :decimal
      add :currency, :string, default: "USD"
      add :wallet_address, :string
      add :contract_address, :string
      add :status, :string, null: false, default: "active"
      add :entry_date, :date
      add :exit_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:defi_positions, [:company_id])
    create index(:defi_positions, [:chain])
    create index(:defi_positions, [:protocol_name])
    create index(:defi_positions, [:status])
  end
end
