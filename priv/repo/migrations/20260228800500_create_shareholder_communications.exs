defmodule Holdco.Repo.Migrations.CreateShareholderCommunications do
  use Ecto.Migration

  def change do
    create table(:shareholder_communications) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :communication_type, :string, null: false
      add :title, :string, null: false
      add :content, :text
      add :target_audience, :string, default: "all_shareholders"
      add :distribution_date, :date
      add :response_deadline, :date
      add :status, :string, default: "draft"
      add :delivery_method, :string, default: "email"
      add :recipients_count, :integer, default: 0
      add :acknowledged_count, :integer, default: 0
      add :documents, {:array, :string}, default: []
      add :notes, :text

      timestamps(type: :utc_datetime)
    end

    create index(:shareholder_communications, [:company_id])
    create index(:shareholder_communications, [:status])
  end
end
