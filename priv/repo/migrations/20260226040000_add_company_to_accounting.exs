defmodule Holdco.Repo.Migrations.AddCompanyToAccounting do
  use Ecto.Migration

  def change do
    alter table(:accounts) do
      add :company_id, references(:companies, on_delete: :nilify_all)
    end

    alter table(:journal_entries) do
      add :company_id, references(:companies, on_delete: :nilify_all)
    end

    create index(:accounts, [:company_id])
    create index(:journal_entries, [:company_id])
  end
end
