defmodule Holdco.Tax.WithholdingReclaim do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  schema "withholding_reclaims" do
    field :jurisdiction, :string
    field :tax_year, :integer
    field :income_type, :string
    field :gross_amount, :decimal
    field :withholding_rate, :decimal
    field :amount_withheld, :decimal
    field :treaty_rate, :decimal
    field :reclaimable_amount, :decimal, default: 0
    field :reclaimed_amount, :decimal, default: 0
    field :status, :string, default: "pending"
    field :filed_date, :string
    field :received_date, :string
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  @income_types ~w(dividend interest royalty)
  @statuses ~w(pending filed partial received denied)

  def changeset(reclaim, attrs) do
    reclaim
    |> cast(attrs, [
      :company_id,
      :jurisdiction,
      :tax_year,
      :income_type,
      :gross_amount,
      :withholding_rate,
      :amount_withheld,
      :treaty_rate,
      :reclaimable_amount,
      :reclaimed_amount,
      :status,
      :filed_date,
      :received_date,
      :notes
    ])
    |> validate_required([
      :company_id,
      :jurisdiction,
      :tax_year,
      :income_type,
      :gross_amount,
      :withholding_rate,
      :amount_withheld
    ])
    |> validate_inclusion(:income_type, @income_types)
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:gross_amount, greater_than: 0)
    |> validate_number(:withholding_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:amount_withheld, greater_than_or_equal_to: 0)
    |> validate_number(:treaty_rate, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> validate_number(:reclaimable_amount, greater_than_or_equal_to: 0)
    |> validate_number(:reclaimed_amount, greater_than_or_equal_to: 0)
    |> maybe_validate_date_field(:filed_date)
    |> maybe_validate_date_field(:received_date)
  end

  defp maybe_validate_date_field(changeset, field) do
    case get_change(changeset, field) do
      nil -> changeset
      _ -> validate_date_format(changeset, field)
    end
  end
end
