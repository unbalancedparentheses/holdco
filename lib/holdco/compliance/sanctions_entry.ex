defmodule Holdco.Compliance.SanctionsEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sanctions_entries" do
    field :name, :string
    field :entity_type, :string, default: "individual"
    field :country, :string, default: ""
    field :identifiers, :string, default: ""
    field :notes, :string, default: ""

    belongs_to :sanctions_list, Holdco.Compliance.SanctionsList

    timestamps(type: :utc_datetime)
  end

  def changeset(sanctions_entry, attrs) do
    sanctions_entry
    |> cast(attrs, [:sanctions_list_id, :name, :entity_type, :country, :identifiers, :notes])
    |> validate_required([:sanctions_list_id, :name])
  end
end
