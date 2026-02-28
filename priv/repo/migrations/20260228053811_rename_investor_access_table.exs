defmodule Holdco.Repo.Migrations.RenameInvestorAccessTable do
  use Ecto.Migration

  def change do
    rename table(:investor_access), to: table(:investor_accesses)
  end
end
