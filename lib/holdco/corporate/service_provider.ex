defmodule Holdco.Corporate.ServiceProvider do
  use Ecto.Schema
  import Ecto.Changeset

  schema "service_providers" do
    field :role, :string
    field :name, :string
    field :firm, :string
    field :email, :string
    field :phone, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(service_provider, attrs) do
    service_provider
    |> cast(attrs, [:company_id, :role, :name, :firm, :email, :phone, :notes])
    |> validate_required([:company_id, :role, :name])
  end
end
