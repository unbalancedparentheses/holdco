defmodule Holdco.Tax.Jurisdiction do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "jurisdictions" do
    field :name, :string
    field :country_code, :string
    field :tax_rate, :decimal
    field :tax_type, :string
    field :effective_date, :string
    field :expiry_date, :string
    field :notes, :string
    field :is_active, :boolean, default: true

    timestamps(type: :utc_datetime)
  end

  @tax_types ~w(income capital_gains withholding vat)

  def changeset(jurisdiction, attrs) do
    jurisdiction
    |> cast(attrs, [
      :name,
      :country_code,
      :tax_rate,
      :tax_type,
      :effective_date,
      :expiry_date,
      :notes,
      :is_active
    ])
    |> validate_required([:name, :country_code, :tax_rate, :tax_type])
    |> validate_inclusion(:tax_type, @tax_types)
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> maybe_validate_date(:effective_date)
    |> maybe_validate_date(:expiry_date)
  end

  defp maybe_validate_date(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      _ -> validate_date_format(changeset, field)
    end
  end
end
