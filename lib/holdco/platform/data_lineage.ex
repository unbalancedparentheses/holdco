defmodule Holdco.Platform.DataLineage do
  use Ecto.Schema
  import Ecto.Changeset

  @source_types ~w(manual_entry import bank_feed api_sync calculation migration)
  @confidence_levels ~w(high medium low)

  schema "data_lineage" do
    field :source_type, :string
    field :source_identifier, :string
    field :target_entity_type, :string
    field :target_entity_id, :integer
    field :transformation, :string
    field :confidence, :string, default: "high"
    field :verified, :boolean, default: false
    field :verified_at, :utc_datetime
    field :notes, :string

    belongs_to :verified_by, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(lineage, attrs) do
    lineage
    |> cast(attrs, [
      :source_type, :source_identifier, :target_entity_type, :target_entity_id,
      :transformation, :confidence, :verified, :verified_by_id, :verified_at, :notes
    ])
    |> validate_required([:source_type, :target_entity_type, :target_entity_id])
    |> validate_inclusion(:source_type, @source_types)
    |> validate_inclusion(:confidence, @confidence_levels)
    |> foreign_key_constraint(:verified_by_id)
  end

  def source_types, do: @source_types
  def confidence_levels, do: @confidence_levels
end
