defmodule Holdco.Corporate.EntityPermission do
  use Ecto.Schema
  import Ecto.Changeset

  schema "entity_permissions" do
    field :permission_level, :string, default: "view"

    belongs_to :user, Holdco.Accounts.User
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(entity_permission, attrs) do
    entity_permission
    |> cast(attrs, [:user_id, :company_id, :permission_level])
    |> validate_required([:user_id, :company_id, :permission_level])
    |> unique_constraint([:user_id, :company_id])
  end
end
