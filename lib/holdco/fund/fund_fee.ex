defmodule Holdco.Fund.FundFee do
  use Ecto.Schema
  import Ecto.Changeset

  schema "fund_fees" do
    field :fee_type, :string
    field :description, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :period_start, :date
    field :period_end, :date
    field :basis, :string
    field :rate_pct, :decimal
    field :calculation_basis_amount, :decimal
    field :status, :string, default: "accrued"
    field :paid_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @valid_fee_types ~w(management performance admin custody legal audit other)
  @valid_statuses ~w(accrued invoiced paid waived)
  @valid_bases ~w(nav committed_capital invested_capital fixed)

  def changeset(fund_fee, attrs) do
    fund_fee
    |> cast(attrs, [
      :company_id,
      :fee_type,
      :description,
      :amount,
      :currency,
      :period_start,
      :period_end,
      :basis,
      :rate_pct,
      :calculation_basis_amount,
      :status,
      :paid_date,
      :notes
    ])
    |> validate_required([:company_id, :fee_type, :amount])
    |> validate_inclusion(:fee_type, @valid_fee_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_inclusion(:basis, @valid_bases ++ [nil])
    |> validate_number(:amount, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end
end
