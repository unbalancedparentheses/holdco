defmodule Holdco.Repo.Migrations.AlterPhase1Tables do
  use Ecto.Migration

  def change do
    # Add diff tracking to audit_logs
    alter table(:audit_logs) do
      add :old_values, :text
      add :new_values, :text
    end

    # Add segment_id to journal_lines
    alter table(:journal_lines) do
      add :segment_id, references(:segments, on_delete: :nilify_all)
    end

    create index(:journal_lines, [:segment_id])

    # Add segment_id to accounts
    alter table(:accounts) do
      add :segment_id, references(:segments, on_delete: :nilify_all)
    end

    create index(:accounts, [:segment_id])

    # Add estimated_amount to tax_deadlines
    alter table(:tax_deadlines) do
      add :estimated_amount, :decimal
    end
  end
end
