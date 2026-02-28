defmodule Holdco.Repo.Migrations.AddPlaidFields do
  use Ecto.Migration

  def change do
    alter table(:bank_feed_configs) do
      add :sync_cursor, :string
      add :institution_id, :string, default: ""
      add :institution_name, :string, default: ""
    end
  end
end
