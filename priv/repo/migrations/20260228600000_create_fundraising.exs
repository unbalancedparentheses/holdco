defmodule Holdco.Repo.Migrations.CreateFundraising do
  use Ecto.Migration

  def change do
    create table(:fundraising_pipelines) do
      add :company_id, references(:companies, on_delete: :delete_all), null: false
      add :fund_name, :string, null: false
      add :target_amount, :decimal, null: false
      add :hard_cap, :decimal
      add :soft_cap, :decimal
      add :amount_raised, :decimal, default: 0
      add :currency, :string, default: "USD"
      add :status, :string, default: "prospecting"
      add :first_close_date, :date
      add :final_close_date, :date
      add :management_fee_rate, :decimal
      add :carried_interest_rate, :decimal
      add :hurdle_rate, :decimal
      add :fund_term_years, :integer
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create table(:prospects) do
      add :pipeline_id, references(:fundraising_pipelines, on_delete: :delete_all), null: false
      add :investor_name, :string, null: false
      add :contact_email, :string
      add :commitment_amount, :decimal
      add :status, :string, default: "identified"
      add :last_contact_date, :date
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create index(:fundraising_pipelines, [:company_id])
    create index(:fundraising_pipelines, [:status])
    create index(:prospects, [:pipeline_id])
    create index(:prospects, [:status])
  end
end
