defmodule Holdco.Platform.PluginHook do
  use Ecto.Schema
  import Ecto.Changeset

  @hook_points ~w(before_save after_save before_delete after_delete on_event scheduled)

  schema "plugin_hooks" do
    field :hook_point, :string
    field :entity_type, :string
    field :handler_function, :string
    field :priority, :integer, default: 50
    field :is_active, :boolean, default: true

    belongs_to :plugin, Holdco.Platform.Plugin

    timestamps(type: :utc_datetime)
  end

  def changeset(plugin_hook, attrs) do
    plugin_hook
    |> cast(attrs, [:plugin_id, :hook_point, :entity_type, :handler_function, :priority, :is_active])
    |> validate_required([:plugin_id, :hook_point, :handler_function])
    |> validate_inclusion(:hook_point, @hook_points)
    |> foreign_key_constraint(:plugin_id)
  end

  def hook_points, do: @hook_points
end
