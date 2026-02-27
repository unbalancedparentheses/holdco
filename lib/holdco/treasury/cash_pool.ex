defmodule Holdco.Treasury.CashPool do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cash_pools" do
    field :name, :string
    field :currency, :string, default: "USD"
    field :target_balance, :decimal, default: 0
    field :notes, :string, default: ""

    has_many :entries, Holdco.Treasury.CashPoolEntry, foreign_key: :pool_id

    timestamps(type: :utc_datetime)
  end

  def changeset(cash_pool, attrs) do
    cash_pool
    |> cast(attrs, [:name, :currency, :target_balance, :notes])
    |> validate_required([:name])
  end
end
