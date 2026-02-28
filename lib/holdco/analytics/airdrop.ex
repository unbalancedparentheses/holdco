defmodule Holdco.Analytics.Airdrop do
  use Ecto.Schema
  import Ecto.Changeset

  @event_types ~w(airdrop fork token_split migration)
  @chains ~w(ethereum polygon arbitrum solana avalanche bsc other)

  schema "airdrops" do
    field :event_type, :string, default: "airdrop"
    field :token_name, :string
    field :chain, :string, default: "ethereum"
    field :amount, :decimal
    field :value_at_receipt, :decimal
    field :current_value, :decimal
    field :currency, :string, default: "USD"
    field :wallet_address, :string
    field :received_date, :date
    field :claimed, :boolean, default: false
    field :claimed_date, :date
    field :eligible, :boolean, default: true
    field :snapshot_date, :date
    field :tax_treated, :boolean, default: false
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(airdrop, attrs) do
    airdrop
    |> cast(attrs, [
      :company_id,
      :event_type,
      :token_name,
      :chain,
      :amount,
      :value_at_receipt,
      :current_value,
      :currency,
      :wallet_address,
      :received_date,
      :claimed,
      :claimed_date,
      :eligible,
      :snapshot_date,
      :tax_treated,
      :notes
    ])
    |> validate_required([:company_id, :event_type, :token_name, :chain])
    |> validate_inclusion(:event_type, @event_types)
    |> validate_inclusion(:chain, @chains)
    |> foreign_key_constraint(:company_id)
  end

  def event_types, do: @event_types
  def chains, do: @chains
end
