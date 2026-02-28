defmodule Holdco.Compliance.RegulatoryChange do
  use Ecto.Schema
  import Ecto.Changeset

  @change_types ~w(new_regulation amendment repeal guidance enforcement)
  @impact_levels ~w(low medium high critical)
  @statuses ~w(monitoring assessment implementation completed)

  schema "regulatory_changes" do
    field :title, :string
    field :jurisdiction, :string
    field :regulatory_body, :string
    field :change_type, :string
    field :effective_date, :date
    field :description, :string
    field :impact_assessment, :string, default: "low"
    field :affected_entities, {:array, :string}, default: []
    field :status, :string, default: "monitoring"
    field :assigned_to, :string
    field :action_items, {:array, :map}, default: []
    field :source_url, :string
    field :notes, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(regulatory_change, attrs) do
    regulatory_change
    |> cast(attrs, [
      :title,
      :jurisdiction,
      :regulatory_body,
      :change_type,
      :effective_date,
      :description,
      :impact_assessment,
      :affected_entities,
      :status,
      :assigned_to,
      :action_items,
      :source_url,
      :notes
    ])
    |> validate_required([:title, :jurisdiction, :change_type])
    |> validate_inclusion(:change_type, @change_types)
    |> validate_inclusion(:impact_assessment, @impact_levels)
    |> validate_inclusion(:status, @statuses)
  end

  def change_types, do: @change_types
  def impact_levels, do: @impact_levels
  def statuses, do: @statuses
end
