defmodule Holdco.Finance.Goodwill do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @statuses ~w(active fully_impaired disposed)

  schema "goodwill" do
    field :acquisition_name, :string
    field :acquisition_date, :string
    field :original_amount, :decimal
    field :accumulated_impairment, :decimal, default: Decimal.new(0)
    field :carrying_value, :decimal
    field :reporting_unit, :string
    field :last_test_date, :string
    field :next_test_date, :string
    field :status, :string, default: "active"
    field :notes, :string

    belongs_to :company, Holdco.Corporate.Company
    has_many :impairment_tests, Holdco.Finance.ImpairmentTest

    timestamps(type: :utc_datetime)
  end

  def changeset(goodwill, attrs) do
    goodwill
    |> cast(attrs, [
      :company_id,
      :acquisition_name,
      :acquisition_date,
      :original_amount,
      :accumulated_impairment,
      :carrying_value,
      :reporting_unit,
      :last_test_date,
      :next_test_date,
      :status,
      :notes
    ])
    |> validate_required([:company_id, :acquisition_name, :original_amount, :carrying_value])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:original_amount, greater_than: 0)
    |> validate_number(:carrying_value, greater_than_or_equal_to: 0)
    |> validate_number(:accumulated_impairment, greater_than_or_equal_to: 0)
    |> validate_date_format(:acquisition_date)
    |> validate_date_format(:last_test_date)
    |> validate_date_format(:next_test_date)
  end
end
