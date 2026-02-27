defmodule Holdco.Governance.CapTableEntry do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "cap_table_entries" do
    field :round_name, :string
    field :investor, :string
    field :instrument_type, :string, default: "equity"
    field :shares, :decimal, default: 0
    field :price_per_share, :decimal
    field :amount_invested, :decimal, default: 0
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
    |> validate_number(:shares, greater_than_or_equal_to: 0)
    |> validate_number(:price_per_share, greater_than: 0)
    |> validate_number(:amount_invested, greater_than_or_equal_to: 0)
    |> validate_date_format(:date)
  end
end
