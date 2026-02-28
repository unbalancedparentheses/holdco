defmodule Holdco.Repo.Migrations.CreateShareClasses do
  use Ecto.Migration

  def change do
    create table(:share_classes) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :class_code, :string, null: false
      add :shares_authorized, :decimal
      add :shares_issued, :decimal
      add :shares_outstanding, :decimal
      add :par_value, :decimal
      add :currency, :string, default: "USD"
      add :voting_rights_per_share, :decimal, default: 1
      add :dividend_preference, :string, default: "none"
      add :liquidation_preference, :decimal
      add :conversion_ratio, :decimal
      add :is_convertible, :boolean, default: false
      add :is_redeemable, :boolean, default: false
      add :status, :string, null: false, default: "active"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:share_classes, [:company_id])
    create index(:share_classes, [:class_code])
    create index(:share_classes, [:status])
    create unique_index(:share_classes, [:company_id, :class_code])
  end
end
