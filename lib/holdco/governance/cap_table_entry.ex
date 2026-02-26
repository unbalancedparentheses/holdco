defmodule Holdco.Governance.CapTableEntry do
  use Ecto.Schema
  import Ecto.Changeset

  schema "cap_table_entries" do
    field :round_name, :string
    field :investor, :string
    field :instrument_type, :string, default: "equity"
    field :shares, :float, default: 0.0
    field :price_per_share, :float
    field :amount_invested, :float, default: 0.0
    field :currency, :string, default: "USD"
    field :date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(cap_table_entry, attrs) do
    cap_table_entry
    |> cast(attrs, [
      :company_id,
      :round_name,
      :investor,
      :instrument_type,
      :shares,
      :price_per_share,
      :amount_invested,
      :currency,
      :date,
      :notes
    ])
    |> validate_required([:company_id, :investor, :round_name])
  end
end
