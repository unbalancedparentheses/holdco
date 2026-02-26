defmodule Holdco.Platform.CustomField do
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_fields" do
    field :name, :string
    field :field_type, :string, default: "text"
    field :entity_type, :string, default: "company"
    field :options, :string, default: "[]"
    field :required, :boolean, default: false

    has_many :values, Holdco.Platform.CustomFieldValue

    timestamps(type: :utc_datetime)
  end

  def changeset(custom_field, attrs) do
    custom_field
    |> cast(attrs, [:name, :field_type, :entity_type, :options, :required])
    |> validate_required([:name])
  end
end
