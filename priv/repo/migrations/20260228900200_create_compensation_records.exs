defmodule Holdco.Repo.Migrations.CreateCompensationRecords do
  use Ecto.Migration

  def change do
    create table(:compensation_records) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :employee_name, :string, null: false
      add :role, :string
      add :department, :string
      add :compensation_type, :string, null: false, default: "salary"
      add :amount, :decimal, null: false
      add :currency, :string, default: "USD"
      add :frequency, :string, null: false, default: "annual"
      add :effective_date, :date
      add :end_date, :date
      add :vesting_schedule, :string
      add :status, :string, null: false, default: "active"
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:compensation_records, [:company_id])
    create index(:compensation_records, [:department])
    create index(:compensation_records, [:compensation_type])
    create index(:compensation_records, [:status])
  end
end
