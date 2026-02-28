defmodule Holdco.Fund.Distribution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "distributions" do
    field :distribution_number, :integer
    field :distribution_date, :date
    field :total_amount, :decimal
    field :currency, :string, default: "USD"
    field :distribution_type, :string
    field :status, :string, default: "pending"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :lines, Holdco.Fund.DistributionLine

    timestamps(type: :utc_datetime)
  end

  def changeset(distribution, attrs) do
    distribution
    |> cast(attrs, [:company_id, :distribution_number, :distribution_date, :total_amount, :currency, :distribution_type, :status, :notes])
    |> validate_required([:company_id, :distribution_date, :total_amount])
    |> validate_inclusion(:distribution_type, ~w(return_of_capital profit dividend liquidation))
    |> validate_inclusion(:status, ~w(pending approved distributed cancelled))
    |> foreign_key_constraint(:company_id)
  end
end
