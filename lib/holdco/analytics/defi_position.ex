defmodule Holdco.Analytics.DefiPosition do
  use Ecto.Schema
  import Ecto.Changeset

  @chains ~w(ethereum polygon arbitrum solana avalanche bsc other)
  @position_types ~w(lending borrowing liquidity_pool staking farming vault other)
  @statuses ~w(active closed liquidated)

  schema "defi_positions" do
    field :protocol_name, :string
    field :chain, :string, default: "ethereum"
    field :position_type, :string, default: "lending"
    field :asset_pair, :string
    field :deposited_amount, :decimal
    field :current_value, :decimal
    field :unrealized_pnl, :decimal
    field :apy_current, :decimal
    field :currency, :string, default: "USD"
    field :wallet_address, :string
    field :contract_address, :string
    field :status, :string, default: "active"
    field :entry_date, :date
    field :exit_date, :date
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(defi_position, attrs) do
    defi_position
    |> cast(attrs, [
      :company_id,
      :protocol_name,
      :chain,
      :position_type,
      :asset_pair,
      :deposited_amount,
      :current_value,
      :unrealized_pnl,
      :apy_current,
      :currency,
      :wallet_address,
      :contract_address,
      :status,
      :entry_date,
      :exit_date,
      :notes
    ])
    |> validate_required([:company_id, :protocol_name, :chain, :position_type])
    |> validate_inclusion(:chain, @chains)
    |> validate_inclusion(:position_type, @position_types)
    |> validate_inclusion(:status, @statuses)
    |> foreign_key_constraint(:company_id)
  end

  def chains, do: @chains
  def position_types, do: @position_types
  def statuses, do: @statuses
end
