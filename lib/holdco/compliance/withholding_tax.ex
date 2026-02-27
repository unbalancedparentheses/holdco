defmodule Holdco.Compliance.WithholdingTax do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "withholding_taxes" do
    field :payment_type, :string
    field :country_from, :string
    field :country_to, :string
    field :gross_amount, :decimal
    field :rate, :decimal
    field :tax_amount, :decimal
    field :currency, :string, default: "USD"
    field :date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(withholding_tax, attrs) do
    withholding_tax
    |> cast(attrs, [
      :company_id,
      :payment_type,
      :country_from,
      :country_to,
      :gross_amount,
      :rate,
      :tax_amount,
      :currency,
      :date,
      :notes
    ])
    |> validate_required([
      :company_id,
      :payment_type,
      :country_from,
      :country_to,
      :gross_amount,
      :rate,
      :tax_amount,
      :date
    ])
    |> validate_number(:gross_amount, greater_than: 0)
    |> validate_number(:rate, greater_than_or_equal_to: 0)
    |> validate_number(:tax_amount, greater_than_or_equal_to: 0)
    |> validate_date_format(:date)
  end
end
