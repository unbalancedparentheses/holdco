defmodule Holdco.Corporate.OwnershipChange do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "ownership_changes" do
    field :date, :string
    field :from_owner, :string
    field :to_owner, :string
    field :ownership_pct, :decimal, default: 0
    field :transaction_type, :string, default: "transfer"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(ownership_change, attrs) do
    ownership_change
    |> cast(attrs, [
      :company_id,
      :date,
      :from_owner,
      :to_owner,
      :ownership_pct,
      :transaction_type,
      :notes
    ])
    |> validate_required([:company_id, :date, :from_owner, :to_owner])
    |> validate_number(:ownership_pct, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> validate_date_format(:date)
  end
end
