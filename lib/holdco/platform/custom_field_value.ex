defmodule Holdco.Platform.CustomFieldValue do
  use Ecto.Schema
  import Ecto.Changeset

  schema "custom_field_values" do
    field :entity_type, :string
    field :entity_id, :integer
    field :value, :string

    belongs_to :custom_field, Holdco.Platform.CustomField

    timestamps(type: :utc_datetime)
  end

  def changeset(custom_field_value, attrs) do
    custom_field_value
    |> cast(attrs, [:custom_field_id, :entity_type, :entity_id, :value])
    |> validate_required([:custom_field_id, :entity_type, :entity_id])
  end
end
