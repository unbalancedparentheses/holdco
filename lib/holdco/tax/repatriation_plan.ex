defmodule Holdco.Tax.RepatriationPlan do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "repatriation_plans" do
    field :source_jurisdiction, :string
    field :target_jurisdiction, :string
    field :amount, :decimal
    field :currency, :string, default: "USD"
    field :mechanism, :string
    field :withholding_tax_rate, :decimal, default: 0
    field :withholding_tax_amount, :decimal, default: 0
    field :effective_tax_rate, :decimal, default: 0
    field :net_amount, :decimal, default: 0
    field :planned_date, :string
    field :status, :string, default: "draft"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @mechanisms ~w(dividend loan_repayment management_fee royalty liquidation)
  @statuses ~w(draft approved executed)

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :company_id,
      :source_jurisdiction,
      :target_jurisdiction,
      :amount,
      :currency,
      :mechanism,
      :withholding_tax_rate,
      :withholding_tax_amount,
      :effective_tax_rate,
      :net_amount,
      :planned_date,
      :status,
      :notes
    ])
    |> validate_required([
      :company_id,
      :source_jurisdiction,
      :target_jurisdiction,
      :amount,
      :mechanism
    ])
    |> validate_inclusion(:mechanism, @mechanisms)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:amount, greater_than: 0)
    |> validate_number(:withholding_tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:withholding_tax_amount, greater_than_or_equal_to: 0)
    |> validate_number(:effective_tax_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:net_amount, greater_than_or_equal_to: 0)
    |> maybe_validate_date_field(:planned_date)
  end

  defp maybe_validate_date_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      _ -> validate_date_format(changeset, field)
    end
  end
end
