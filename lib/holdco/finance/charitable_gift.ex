defmodule Holdco.Finance.CharitableGift do
  use Ecto.Schema
  import Ecto.Changeset

  @recipient_types ~w(501c3 daf private_foundation public_charity religious educational other)
  @gift_types ~w(cash securities property in_kind pledge)

  schema "charitable_gifts" do
    field :recipient_name, :string
    field :recipient_type, :string, default: "501c3"
    field :ein_number, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :gift_type, :string, default: "cash"
    field :fair_market_value, :decimal
    field :cost_basis, :decimal
    field :gift_date, :date
    field :tax_year, :integer
    field :tax_deductible, :boolean, default: true
    field :deduction_limit_pct, :decimal
    field :acknowledgment_received, :boolean, default: false
    field :acknowledgment_date, :date
    field :pledge_amount, :decimal
    field :pledge_fulfilled, :boolean, default: false
    field :restricted_purpose, :string
    field :grant_agreement_id, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(charitable_gift, attrs) do
    charitable_gift
    |> cast(attrs, [
      :company_id,
      :recipient_name,
      :recipient_type,
      :ein_number,
      :amount,
      :currency,
      :gift_type,
      :fair_market_value,
      :cost_basis,
      :gift_date,
      :tax_year,
      :tax_deductible,
      :deduction_limit_pct,
      :acknowledgment_received,
      :acknowledgment_date,
      :pledge_amount,
      :pledge_fulfilled,
      :restricted_purpose,
      :grant_agreement_id,
      :notes
    ])
    |> validate_required([:company_id, :recipient_name, :amount, :gift_date])
    |> validate_inclusion(:recipient_type, @recipient_types)
    |> validate_inclusion(:gift_type, @gift_types)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:company_id)
  end

  def recipient_types, do: @recipient_types
  def gift_types, do: @gift_types
end
