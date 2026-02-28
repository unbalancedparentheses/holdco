defmodule Holdco.Repo.Migrations.CreateSignatureWorkflows do
  use Ecto.Migration

  def change do
    create table(:signature_workflows) do
      add :document_id, references(:documents, on_delete: :nilify_all)
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :title, :string, null: false
      add :status, :string, default: "draft"
      add :created_by, :string
      add :signers, {:array, :map}, default: []
      add :expiry_date, :date
      add :reminder_frequency, :string, default: "none"
      add :last_reminder_sent, :utc_datetime
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:signature_workflows, [:company_id])
    create index(:signature_workflows, [:document_id])
    create index(:signature_workflows, [:status])
  end
end
