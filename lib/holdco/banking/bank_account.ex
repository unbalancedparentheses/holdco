defmodule Holdco.Banking.BankAccount do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bank_accounts" do
    field :bank_name, :string
    field :account_number, :string
    field :iban, :string
    field :swift, :string
    field :currency, :string, default: "USD"
    field :account_type, :string, default: "operating"
    field :balance, :decimal, default: 0
    field :authorized_signers, :string, default: "[]"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(bank_account, attrs) do
    bank_account
    |> cast(attrs, [
      :company_id,
      :bank_name,
      :account_number,
      :iban,
      :swift,
      :currency,
      :account_type,
      :balance,
      :authorized_signers,
      :notes
    ])
    |> validate_required([:company_id, :bank_name])
  end
end
