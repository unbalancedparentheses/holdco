defmodule Holdco.Fund.DistributionLine do
  use Ecto.Schema
  import Ecto.Changeset

  schema "distribution_lines" do
    field :investor_name, :string
    field :ownership_pct, :decimal
    field :gross_amount, :decimal
    field :withholding_tax, :decimal, default: Decimal.new(0)
    field :net_amount, :decimal
    field :status, :string, default: "pending"

    belongs_to :distribution, Holdco.Fund.Distribution

    timestamps(type: :utc_datetime)
  end

  def changeset(line, attrs) do
    line
    |> cast(attrs, [:distribution_id, :investor_name, :ownership_pct, :gross_amount, :withholding_tax, :net_amount, :status])
    |> validate_required([:distribution_id, :investor_name, :gross_amount])
    |> validate_inclusion(:status, ~w(pending distributed))
    |> foreign_key_constraint(:distribution_id)
  end
end
