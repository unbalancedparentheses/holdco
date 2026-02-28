defmodule Holdco.Repo.Migrations.CreateEthicsReports do
  use Ecto.Migration

  def change do
    create table(:ethics_reports) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :report_type, :string, null: false, default: "whistleblower"
      add :reporter_type, :string, null: false, default: "anonymous"
      add :reporter_name, :string
      add :severity, :string, null: false, default: "medium"
      add :description, :text, null: false
      add :involved_parties, :string
      add :status, :string, null: false, default: "received"
      add :assigned_investigator, :string
      add :investigation_notes, :text
      add :resolution, :text
      add :reported_date, :date, null: false
      add :resolved_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:ethics_reports, [:company_id])
    create index(:ethics_reports, [:report_type])
    create index(:ethics_reports, [:severity])
    create index(:ethics_reports, [:status])
    create index(:ethics_reports, [:reported_date])
  end
end
