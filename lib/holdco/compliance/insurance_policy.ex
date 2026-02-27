defmodule Holdco.Compliance.InsurancePolicy do
  use Ecto.Schema
  import Ecto.Changeset

  schema "insurance_policies" do
    field :policy_type, :string
    field :provider, :string
    field :policy_number, :string
    field :coverage_amount, :decimal
    field :premium, :decimal
    field :currency, :string, default: "USD"
    field :start_date, :string
    field :expiry_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(insurance_policy, attrs) do
    insurance_policy
    |> cast(attrs, [
      :company_id,
      :policy_type,
      :provider,
      :policy_number,
      :coverage_amount,
      :premium,
      :currency,
      :start_date,
      :expiry_date,
      :notes
    ])
    |> validate_required([:company_id, :policy_type, :provider])
  end
end
