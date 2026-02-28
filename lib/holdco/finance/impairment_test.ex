defmodule Holdco.Finance.ImpairmentTest do
  use Ecto.Schema
  import Ecto.Changeset
  import Holdco.Validators

  @methods ~w(income_approach market_approach cost_approach)
  @results ~w(no_impairment impairment_recognized)

  schema "impairment_tests" do
    field :test_date, :string
    field :fair_value, :decimal
    field :carrying_amount, :decimal
    field :impairment_amount, :decimal, default: Decimal.new(0)
    field :method, :string
    field :discount_rate, :decimal
    field :growth_rate, :decimal
    field :assumptions, :string
    field :result, :string
    field :notes, :string

    belongs_to :goodwill, Holdco.Finance.Goodwill

    timestamps(type: :utc_datetime)
  end

  def changeset(impairment_test, attrs) do
    impairment_test
    |> cast(attrs, [
      :goodwill_id,
      :test_date,
      :fair_value,
      :carrying_amount,
      :impairment_amount,
      :method,
      :discount_rate,
      :growth_rate,
      :assumptions,
      :result,
      :notes
    ])
    |> validate_required([:goodwill_id, :test_date, :fair_value, :carrying_amount, :method, :result])
    |> validate_inclusion(:method, @methods)
    |> validate_inclusion(:result, @results)
    |> validate_number(:fair_value, greater_than_or_equal_to: 0)
    |> validate_number(:carrying_amount, greater_than_or_equal_to: 0)
    |> validate_number(:impairment_amount, greater_than_or_equal_to: 0)
    |> validate_date_format(:test_date)
  end
end
