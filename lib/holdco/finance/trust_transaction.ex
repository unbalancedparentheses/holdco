defmodule Holdco.Finance.TrustTransaction do
  use Ecto.Schema
  import Ecto.Changeset

  @transaction_types ~w(contribution distribution income expense fee tax_payment)
  @categories ~w(principal income)

  schema "trust_transactions" do
    field :transaction_type, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :description, :string
    field :counterparty, :string
    field :transaction_date, :date
    field :category, :string, default: "principal"
    field :approved_by, :string
    field :notes, :string

    belongs_to :trust_account, Holdco.Finance.TrustAccount

    timestamps(type: :utc_datetime)
  end

  def changeset(trust_transaction, attrs) do
    trust_transaction
    |> cast(attrs, [
      :trust_account_id,
      :transaction_type,
      :amount,
      :currency,
      :description,
      :counterparty,
      :transaction_date,
      :category,
      :approved_by,
      :notes
    ])
    |> validate_required([:trust_account_id, :transaction_type, :amount, :transaction_date])
    |> validate_inclusion(:transaction_type, @transaction_types)
    |> validate_inclusion(:category, @categories)
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:trust_account_id)
  end

  def transaction_types, do: @transaction_types
  def categories, do: @categories
end
