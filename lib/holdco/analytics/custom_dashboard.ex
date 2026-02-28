defmodule Holdco.Analytics.CustomDashboard do
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_dashboards" do
    field :name, :string
    field :description, :string
    field :layout, :map, default: %{}
    field :is_default, :boolean, default: false
    field :is_shared, :boolean, default: false
    field :widgets, {:array, :map}, default: []
    field :theme, :string, default: "light"
    field :refresh_interval_seconds, :integer, default: 300
    field :notes, :string

    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(dashboard, attrs) do
    dashboard
    |> cast(attrs, [
      :user_id,
      :name,
      :description,
      :layout,
      :is_default,
      :is_shared,
      :widgets,
      :theme,
      :refresh_interval_seconds,
      :notes
    ])
    |> validate_required([:user_id, :name])
    |> validate_inclusion(:theme, ~w(light dark auto))
    |> validate_number(:refresh_interval_seconds, greater_than: 0)
    |> foreign_key_constraint(:user_id)
  end
end
