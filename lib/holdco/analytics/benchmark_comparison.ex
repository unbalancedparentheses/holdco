defmodule Holdco.Analytics.BenchmarkComparison do
  use Ecto.Schema
  import Ecto.Changeset

  schema "benchmark_comparisons" do
    field :period_start, :date
    field :period_end, :date
    field :portfolio_return, :decimal
    field :benchmark_return, :decimal
    field :alpha, :decimal
    field :tracking_error, :decimal
    field :information_ratio, :decimal
    field :notes, :string

    belongs_to :benchmark, Holdco.Analytics.Benchmark
    belongs_to :company, Holdco.Corporate.Company

    timestamps(type: :utc_datetime)
  end

  def changeset(comparison, attrs) do
    comparison
    |> cast(attrs, [
      :benchmark_id, :company_id, :period_start, :period_end,
      :portfolio_return, :benchmark_return, :alpha, :tracking_error,
      :information_ratio, :notes
    ])
    |> validate_required([:benchmark_id, :period_start, :period_end])
    |> foreign_key_constraint(:benchmark_id)
  end
end
