defmodule Holdco.Corporate.OwnershipChange do
  use Ecto.Schema
  import Ecto.Changeset

  schema "ownership_changes" do
    field :date, :string
    field :from_owner, :string
    field :to_owner, :string
    field :ownership_pct, :float, default: 0.0
    field :transaction_type, :string, default: "transfer"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(ownership_change, attrs) do
    ownership_change
    |> cast(attrs, [:company_id, :date, :from_owner, :to_owner, :ownership_pct,
                     :transaction_type, :notes])
    |> validate_required([:company_id, :date, :from_owner, :to_owner])
  end
end
