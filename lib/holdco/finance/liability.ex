defmodule Holdco.Finance.Liability do
  use Ecto.Schema
  import Ecto.Changeset

  schema "liabilities" do
    field :liability_type, :string
    field :creditor, :string
    field :principal, :decimal
    field :currency, :string, default: "USD"
    field :interest_rate, :decimal
    field :maturity_date, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(liability, attrs) do
    liability
    |> cast(attrs, [
      :company_id,
      :liability_type,
      :creditor,
      :principal,
      :currency,
      :interest_rate,
      :maturity_date,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :liability_type, :creditor, :principal])
    |> validate_number(:principal, greater_than: 0)
    |> validate_number(:interest_rate, greater_than_or_equal_to: 0)
  end
end
