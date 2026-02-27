defmodule Holdco.Finance.CapitalContribution do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "capital_contributions" do
    field :contributor, :string
    field :amount, :decimal
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
    |> validate_number(:amount, greater_than: 0)
    |> validate_date_format(:date)
  end
end
