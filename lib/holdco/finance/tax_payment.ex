defmodule Holdco.Finance.TaxPayment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tax_payments" do
    field :jurisdiction, :string
    field :tax_type, :string
    field :amount, :float
    field :currency, :string, default: "USD"
    field :date, :string
    field :period, :string
    field :status, :string, default: "paid"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(tax_payment, attrs) do
    tax_payment
    |> cast(attrs, [:company_id, :jurisdiction, :tax_type, :amount, :currency,
                     :date, :period, :status, :notes])
    |> validate_required([:company_id, :jurisdiction, :tax_type, :amount, :date])
  end
end
