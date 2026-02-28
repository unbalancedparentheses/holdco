defmodule Holdco.Fund.PartnershipBasis do
  use Ecto.Schema
  import Ecto.Changeset

  schema "partnership_bases" do
    field :partner_name, :string
    field :tax_year, :integer
    field :beginning_basis, :decimal, default: 0
    field :capital_contributions, :decimal, default: 0
    field :share_of_income, :decimal, default: 0
    field :share_of_losses, :decimal, default: 0
    field :distributions_received, :decimal, default: 0
    field :special_allocations, :decimal, default: 0
    field :section_754_adjustments, :decimal, default: 0
    field :ending_basis, :decimal, default: 0
    field :at_risk_amount, :decimal, default: 0
    field :passive_activity_amount, :decimal, default: 0
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(basis, attrs) do
    basis
    |> cast(attrs, [
      :company_id,
      :partner_name,
      :tax_year,
      :beginning_basis,
      :capital_contributions,
      :share_of_income,
      :share_of_losses,
      :distributions_received,
      :special_allocations,
      :section_754_adjustments,
      :ending_basis,
      :at_risk_amount,
      :passive_activity_amount,
      :notes
    ])
    |> validate_required([:company_id, :partner_name, :tax_year])
    |> foreign_key_constraint(:company_id)
  end
end
