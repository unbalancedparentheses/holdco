defmodule Holdco.Analytics.OnChainRecord do
  use Ecto.Schema
  import Ecto.Changeset

  @chains ~w(ethereum polygon arbitrum solana avalanche bsc other)
  @verification_statuses ~w(pending confirmed failed mismatch)

  schema "on_chain_records" do
    field :chain, :string, default: "ethereum"
    field :tx_hash, :string
    field :block_number, :integer
    field :from_address, :string
    field :to_address, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :verified_at, :utc_datetime
    field :verification_status, :string, default: "pending"
    field :gas_fee, :decimal
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    belongs_to :matched_transaction, Holdco.Banking.Transaction

    timestamps(type: :utc_datetime)
  end

  def changeset(on_chain_record, attrs) do
    on_chain_record
    |> cast(attrs, [
      :company_id,
      :chain,
      :tx_hash,
      :block_number,
      :from_address,
      :to_address,
      :amount,
      :currency,
      :verified_at,
      :verification_status,
      :matched_transaction_id,
      :gas_fee,
      :notes
    ])
    |> validate_required([:company_id, :chain, :tx_hash])
    |> validate_inclusion(:chain, @chains)
    |> validate_inclusion(:verification_status, @verification_statuses)
    |> unique_constraint(:tx_hash)
    |> foreign_key_constraint(:company_id)
    |> foreign_key_constraint(:matched_transaction_id)
  end

  def chains, do: @chains
  def verification_statuses, do: @verification_statuses
end
