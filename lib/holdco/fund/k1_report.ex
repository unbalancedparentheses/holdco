defmodule Holdco.Fund.K1Report do
  use Ecto.Schema
  import Ecto.Changeset

  schema "k1_reports" do
    field :tax_year, :integer
    field :investor_name, :string
    field :ordinary_income, :decimal, default: Decimal.new(0)
    field :short_term_capital_gains, :decimal, default: Decimal.new(0)
    field :long_term_capital_gains, :decimal, default: Decimal.new(0)
    field :tax_exempt_income, :decimal, default: Decimal.new(0)
    field :section_179_deduction, :decimal, default: Decimal.new(0)
    field :other_deductions, :decimal, default: Decimal.new(0)
    field :total_distributions, :decimal, default: Decimal.new(0)
    field :beginning_capital, :decimal, default: Decimal.new(0)
    field :ending_capital, :decimal, default: Decimal.new(0)
    field :status, :string, default: "draft"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(k1, attrs) do
    k1
    |> cast(attrs, [
      :company_id, :tax_year, :investor_name,
      :ordinary_income, :short_term_capital_gains, :long_term_capital_gains,
      :tax_exempt_income, :section_179_deduction, :other_deductions,
      :total_distributions, :beginning_capital, :ending_capital,
      :status, :notes
    ])
    |> validate_required([:company_id, :tax_year, :investor_name])
    |> validate_inclusion(:status, ~w(draft review final filed))
    |> foreign_key_constraint(:company_id)
  end
end
