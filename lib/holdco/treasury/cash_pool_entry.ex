defmodule Holdco.Treasury.CashPoolEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cash_pool_entries" do
    field :allocated_amount, :decimal, default: 0
    field :notes, :string, default: ""

    belongs_to :pool, Holdco.Treasury.CashPool
    belongs_to :company, Holdco.Corporate.Company
    belongs_to :bank_account, Holdco.Banking.BankAccount

    timestamps(type: :utc_datetime)
  end

  def changeset(cash_pool_entry, attrs) do
    cash_pool_entry
    |> cast(attrs, [:pool_id, :company_id, :bank_account_id, :allocated_amount, :notes])
    |> validate_required([:pool_id, :company_id])
  end
end
