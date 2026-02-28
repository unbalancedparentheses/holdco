defmodule Holdco.Finance.BankGuarantee do
  use Ecto.Schema
  import Ecto.Changeset

  @guarantee_types ~w(performance financial bid advance_payment loc standby_loc)
  @statuses ~w(active expired called released renewed)

  schema "bank_guarantees" do
    field :guarantee_type, :string, default: "performance"
    field :issuing_bank, :string
    field :beneficiary, :string
    field :reference_number, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :issue_date, :date
    field :expiry_date, :date
    field :status, :string, default: "active"
    field :annual_fee_pct, :decimal
    field :collateral_description, :string
    field :purpose, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(bank_guarantee, attrs) do
    bank_guarantee
    |> cast(attrs, [
      :company_id,
      :guarantee_type,
      :issuing_bank,
      :beneficiary,
      :reference_number,
      :amount,
      :currency,
      :issue_date,
      :expiry_date,
      :status,
      :annual_fee_pct,
      :collateral_description,
      :purpose,
      :notes
    ])
    |> validate_required([:company_id, :guarantee_type, :issuing_bank, :beneficiary, :amount])
    |> validate_inclusion(:guarantee_type, @guarantee_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:annual_fee_pct, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:company_id)
  end

  def guarantee_types, do: @guarantee_types
  def statuses, do: @statuses
end
