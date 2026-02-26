defmodule Holdco.Compliance.TransferPricingDoc do
  use Ecto.Schema
  import Ecto.Changeset

  schema "transfer_pricing_docs" do
    field :description, :string
    field :method, :string, default: "comparable_uncontrolled"
    field :amount, :float, default: 0.0
    field :currency, :string, default: "USD"
    field :period, :string
    field :notes, :string

    belongs_to :from_company, Holdco.Corporate.Company
    belongs_to :to_company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(transfer_pricing_doc, attrs) do
    transfer_pricing_doc
    |> cast(attrs, [
      :from_company_id,
      :to_company_id,
      :description,
      :method,
      :amount,
      :currency,
      :period,
      :notes
    ])
    |> validate_required([:from_company_id, :to_company_id, :description])
  end
end
