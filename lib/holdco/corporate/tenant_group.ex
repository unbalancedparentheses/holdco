defmodule Holdco.Corporate.TenantGroup do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tenant_groups" do
    field :name, :string
    field :slug, :string

    has_many :tenant_memberships, Holdco.Corporate.TenantMembership, foreign_key: :tenant_id

    timestamps(type: :utc_datetime)
  end

  def changeset(tenant_group, attrs) do
    tenant_group
    |> cast(attrs, [:name, :slug])
    |> validate_required([:name, :slug])
    |> unique_constraint(:slug)
  end
end
