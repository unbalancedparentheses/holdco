defmodule Holdco.Tax.TaxProvision do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tax_provisions" do
    field :tax_year, :integer
    field :jurisdiction, :string
    field :provision_type, :string
    field :tax_type, :string, default: "income"
    field :taxable_income, :decimal, default: 0
    field :tax_rate, :decimal
    field :tax_amount, :decimal
    field :status, :string, default: "estimated"
    field :due_date, :date
    field :paid_date, :date
    field :paid_amount, :decimal
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @required_fields [:company_id, :tax_year, :jurisdiction, :provision_type]
  @optional_fields [
    :tax_type,
    :taxable_income,
    :tax_rate,
    :tax_amount,
    :status,
    :due_date,
    :paid_date,
    :paid_amount,
    :notes
  ]

  @provision_types ~w(current deferred)
  @tax_types ~w(income capital_gains withholding vat other)
  @statuses ~w(estimated accrued filed paid adjusted)

  def changeset(provision, attrs) do
    provision
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:provision_type, @provision_types)
    |> validate_inclusion(:tax_type, @tax_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:tax_year, greater_than: 1900, less_than: 2200)
    |> validate_number(:tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> foreign_key_constraint(:company_id)
  end
end
