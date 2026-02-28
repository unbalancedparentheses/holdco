defmodule Holdco.Repo.Migrations.CreateServiceAgreements do
  use Ecto.Migration

  def change do
    create table(:service_agreements) do
      add :provider_company_id, references(:companies, on_delete: :delete_all), null: false
      add :recipient_company_id, references(:companies, on_delete: :delete_all), null: false
      add :agreement_type, :string, null: false
      add :description, :text
      add :amount, :decimal
      add :currency, :string, default: "USD"
      add :frequency, :string, default: "monthly"
      add :start_date, :string
      add :end_date, :string
      add :markup_pct, :decimal
      add :arm_length_basis, :text
      add :transfer_pricing_method, :string
      add :status, :string, default: "draft"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:service_agreements, [:provider_company_id])
    create index(:service_agreements, [:recipient_company_id])
    create index(:service_agreements, [:status])
    create index(:service_agreements, [:agreement_type])
  end
end
