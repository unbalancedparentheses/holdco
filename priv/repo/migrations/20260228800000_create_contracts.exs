defmodule Holdco.Repo.Migrations.CreateContracts do
  use Ecto.Migration

  def change do
    create table(:contracts) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :counterparty, :string, null: false
      add :contract_type, :string, null: false, default: "other"
      add :start_date, :date
      add :end_date, :date
      add :auto_renew, :boolean, default: false
      add :renewal_notice_days, :integer
      add :value, :decimal
      add :currency, :string, default: "USD"
      add :payment_terms, :string
      add :status, :string, null: false, default: "draft"
      add :signed_date, :date
      add :termination_date, :date
      add :termination_reason, :string
      add :key_terms, :text
      add :tags, {:array, :string}, default: []
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:contracts, [:company_id])
    create index(:contracts, [:counterparty])
    create index(:contracts, [:contract_type])
    create index(:contracts, [:status])
    create index(:contracts, [:end_date])
  end
end
