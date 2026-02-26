defmodule Holdco.Finance.Lease do
  use Ecto.Schema
  import Ecto.Changeset

  schema "leases" do
    field :lessor, :string
    field :asset_description, :string
    field :start_date, :string
    field :end_date, :string
    field :monthly_payment, :float
    field :discount_rate, :float, default: 0.05
    field :lease_type, :string, default: "operating"
    field :currency, :string, default: "USD"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(lease, attrs) do
    lease
    |> cast(attrs, [
      :lessor, :asset_description, :start_date, :end_date,
      :monthly_payment, :discount_rate, :lease_type, :currency,
      :notes, :company_id
    ])
    |> validate_required([:lessor, :company_id])
    |> validate_inclusion(:lease_type, ~w(operating finance))
  end
end
