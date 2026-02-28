defmodule Holdco.Repo.Migrations.CreateScheduledReports do
  use Ecto.Migration

  def change do
    create table(:scheduled_reports) do
      add :name, :string, null: false
      add :report_type, :string, null: false
      add :frequency, :string, null: false
      add :recipients, :string, null: false
      add :format, :string, default: "html"
      add :is_active, :boolean, default: true
      add :last_sent_at, :utc_datetime
      add :next_run_date, :string
      add :filters, :string
      add :notes, :string
      add :company_id, references(:companies, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:scheduled_reports, [:company_id])
    create index(:scheduled_reports, [:is_active])
    create index(:scheduled_reports, [:next_run_date])
  end
end
