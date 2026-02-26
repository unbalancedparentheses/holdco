defmodule Holdco.Accounts.UserRole do
  use Ecto.Schema
  import Ecto.Changeset

  schema "user_roles" do
    field :role, :string, default: "viewer"
    belongs_to :user, Holdco.Accounts.User
    timestamps(type: :utc_datetime)
  end

  def changeset(user_role, attrs) do
    user_role
    |> cast(attrs, [:role, :user_id])
    |> validate_required([:role, :user_id])
    |> validate_inclusion(:role, ~w(admin editor viewer))
    |> unique_constraint(:user_id)
  end
end
