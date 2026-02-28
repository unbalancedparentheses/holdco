defmodule Holdco.Platform.CollaborationSession do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collaboration_sessions" do
    field :entity_type, :string
    field :entity_id, :integer
    field :started_at, :utc_datetime
    field :last_active_at, :utc_datetime
    field :is_active, :boolean, default: true
    field :notes, {:array, :map}, default: []

    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(session, attrs) do
    session
    |> cast(attrs, [:entity_type, :entity_id, :user_id, :started_at, :last_active_at, :is_active, :notes])
    |> validate_required([:entity_type, :entity_id, :user_id])
    |> foreign_key_constraint(:user_id)
    |> set_defaults()
  end

  defp set_defaults(changeset) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    changeset
    |> put_default(:started_at, now)
    |> put_default(:last_active_at, now)
  end

  defp put_default(changeset, field, value) do
    if get_field(changeset, field) do
      changeset
    else
      put_change(changeset, field, value)
    end
  end
end
