defmodule Holdco.Repo.Migrations.AddCompanyIdToIntegrations do
  use Ecto.Migration

  def change do
    alter table(:integrations) do
      add :company_id, references(:companies, on_delete: :delete_all)
    end

    drop unique_index(:integrations, [:provider])
    create unique_index(:integrations, [:provider, :company_id])
  end
end
