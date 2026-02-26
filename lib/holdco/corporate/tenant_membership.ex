defmodule Holdco.Corporate.TenantMembership do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenant_memberships" do
    field :role, :string, default: "member"

    belongs_to :tenant, Holdco.Corporate.TenantGroup
    belongs_to :user, Holdco.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant_membership, attrs) do
    tenant_membership
    |> cast(attrs, [:tenant_id, :user_id, :role])
    |> validate_required([:tenant_id, :user_id, :role])
    |> unique_constraint([:tenant_id, :user_id])
  end
end
