defmodule Holdco.Compliance.SanctionsList do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sanctions_lists" do
    field :name, :string
    field :list_type, :string
    field :source_url, :string, default: ""
    field :last_updated, :utc_datetime
    field :entry_count, :integer, default: 0

    has_many :entries, Holdco.Compliance.SanctionsEntry, foreign_key: :sanctions_list_id

    timestamps(type: :utc_datetime)
  end

  def changeset(sanctions_list, attrs) do
    sanctions_list
    |> cast(attrs, [:name, :list_type, :source_url, :last_updated, :entry_count])
    |> validate_required([:name, :list_type])
  end
end
