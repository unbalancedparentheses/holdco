defmodule Holdco.Compliance.WithholdingTax do
  use Ecto.Schema
  import Ecto.Changeset

  schema "withholding_taxes" do
    field :payment_type, :string
    field :country_from, :string
    field :country_to, :string
    field :gross_amount, :float
    field :rate, :float
    field :tax_amount, :float
    field :currency, :string, default: "USD"
    field :date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(withholding_tax, attrs) do
    withholding_tax
    |> cast(attrs, [:company_id, :payment_type, :country_from, :country_to,
                     :gross_amount, :rate, :tax_amount, :currency, :date, :notes])
    |> validate_required([:company_id, :payment_type, :country_from, :country_to,
                          :gross_amount, :rate, :tax_amount, :date])
  end
end
