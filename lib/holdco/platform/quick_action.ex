defmodule Holdco.Platform.QuickAction do
  use Ecto.Schema
  import Ecto.Changeset

  @action_types ~w(navigate create search export)
  @categories ~w(portfolio fund corporate accounting tax risk reports settings)

  schema "quick_actions" do
    field :name, :string
    field :description, :string
    field :action_type, :string
    field :target_path, :string
    field :icon, :string
    field :category, :string
    field :search_keywords, {:array, :string}, default: []
    field :sort_order, :integer, default: 0
    field :is_enabled, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [
      :name, :description, :action_type, :target_path, :icon,
      :category, :search_keywords, :sort_order, :is_enabled
    ])
    |> validate_required([:name, :action_type, :target_path])
    |> validate_inclusion(:action_type, @action_types)
    |> validate_inclusion(:category, @categories)
    |> unique_constraint(:name)
  end

  def action_types, do: @action_types
  def categories, do: @categories
end
