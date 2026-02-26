defmodule Holdco.Finance.CapitalContribution do
  use Ecto.Schema
  import Ecto.Changeset

  schema "capital_contributions" do
    field :contributor, :string
    field :amount, :float
    field :currency, :string, default: "USD"
    field :date, :string
    field :contribution_type, :string, default: "cash"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(capital_contribution, attrs) do
    capital_contribution
    |> cast(attrs, [
      :company_id,
      :contributor,
      :amount,
      :currency,
      :date,
      :contribution_type,
      :notes
    ])
    |> validate_required([:company_id, :contributor, :amount, :date])
  end
end
