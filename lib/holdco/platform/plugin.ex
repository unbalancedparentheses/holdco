defmodule Holdco.Platform.Plugin do
  use Ecto.Schema
  import Ecto.Changeset

  @plugin_types ~w(integration report widget automation data_source)
  @statuses ~w(installed active disabled error)

  schema "plugins" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :version, :string
    field :author, :string
    field :plugin_type, :string
    field :status, :string, default: "installed"
    field :config, :map, default: %{}
    field :permissions_required, {:array, :string}, default: []
    field :entry_module, :string
    field :installed_at, :utc_datetime
    field :last_activated_at, :utc_datetime
    field :error_log, :string
    field :notes, :string

    has_many :hooks, Holdco.Platform.PluginHook

    timestamps(type: :utc_datetime)
  end

  def changeset(plugin, attrs) do
    plugin
    |> cast(attrs, [
      :name, :slug, :description, :version, :author, :plugin_type,
      :status, :config, :permissions_required, :entry_module,
      :installed_at, :last_activated_at, :error_log, :notes
    ])
    |> validate_required([:name, :slug, :plugin_type])
    |> validate_inclusion(:plugin_type, @plugin_types)
    |> validate_inclusion(:status, @statuses)
    |> unique_constraint(:slug)
  end

  def plugin_types, do: @plugin_types
  def statuses, do: @statuses
end
