defmodule Holdco.Accounts.ApiKey do
  use Ecto.Schema
  import Ecto.Changeset

  schema "api_keys" do
    field :key, :string
    field :name, :string
    field :is_active, :boolean, default: true
    field :last_used_at, :utc_datetime
    belongs_to :user, Holdco.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(api_key, attrs) do
    api_key
    |> cast(attrs, [:key, :name, :is_active, :last_used_at, :user_id])
    |> validate_required([:key, :name, :user_id])
    |> unique_constraint(:key)
  end
end
