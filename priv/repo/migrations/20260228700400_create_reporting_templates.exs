defmodule Holdco.Repo.Migrations.CreateReportingTemplates do
  use Ecto.Migration

  def change do
    create table(:reporting_templates) do
      add :name, :string, null: false
      add :template_type, :string, null: false, default: "crs"
      add :jurisdiction, :string
      add :frequency, :string, null: false, default: "annual"
      add :due_date_formula, :string
      add :fields, :map, default: %{}
      add :is_active, :boolean, default: true
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:reporting_templates, [:template_type])
    create index(:reporting_templates, [:is_active])
  end
end
