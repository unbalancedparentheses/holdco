defmodule Holdco.Tax.DeferredTax do
  use Ecto.Schema
  import Ecto.Changeset

  schema "deferred_taxes" do
    field :tax_year, :integer
    field :description, :string
    field :deferred_type, :string
    field :source, :string
    field :book_basis, :decimal
    field :tax_basis, :decimal
    field :temporary_difference, :decimal
    field :tax_rate, :decimal
    field :deferred_amount, :decimal
    field :is_current, :boolean, default: false
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @required_fields [:company_id, :tax_year, :description, :deferred_type]
  @optional_fields [
    :source,
    :book_basis,
    :tax_basis,
    :temporary_difference,
    :tax_rate,
    :deferred_amount,
    :is_current,
    :notes
  ]

  @deferred_types ~w(asset liability)
  @sources ~w(depreciation unrealized_gains accrued_expenses nol_carryforward lease_liability)

  def changeset(deferred_tax, attrs) do
    deferred_tax
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:deferred_type, @deferred_types)
    |> validate_source()
    |> validate_number(:tax_year, greater_than: 1900, less_than: 2200)
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:company_id)
  end

  defp validate_source(changeset) do
    case get_change(changeset, :source) do
      nil -> changeset
      value when value in @sources -> changeset
      _ -> add_error(changeset, :source, "is invalid")
    end
  end
end
