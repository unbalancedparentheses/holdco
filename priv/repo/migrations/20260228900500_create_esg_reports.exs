defmodule Holdco.Repo.Migrations.CreateEsgReports do
  use Ecto.Migration

  def change do
    create table(:esg_reports) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :framework, :string, null: false, default: "gri"
      add :reporting_period_start, :date, null: false
      add :reporting_period_end, :date, null: false
      add :title, :string, null: false
      add :metrics, :map, default: %{}
      add :score, :decimal
      add :status, :string, null: false, default: "draft"
      add :published_date, :date
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:esg_reports, [:company_id])
    create index(:esg_reports, [:framework])
    create index(:esg_reports, [:status])
    create index(:esg_reports, [:reporting_period_end])
  end
end
