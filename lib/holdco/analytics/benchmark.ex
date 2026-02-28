defmodule Holdco.Analytics.Benchmark do
  use Ecto.Schema
  import Ecto.Changeset

  @benchmark_types ~w(index custom peer_group)

  schema "benchmarks" do
    field :name, :string
    field :description, :string
    field :benchmark_type, :string
    field :ticker, :string
    field :data_points, :map
    field :is_active, :boolean, default: true

    has_many :comparisons, Holdco.Analytics.BenchmarkComparison

    timestamps(type: :utc_datetime)
  end

  def changeset(benchmark, attrs) do
    benchmark
    |> cast(attrs, [:name, :description, :benchmark_type, :ticker, :data_points, :is_active])
    |> validate_required([:name, :benchmark_type])
    |> validate_inclusion(:benchmark_type, @benchmark_types)
  end

  def benchmark_types, do: @benchmark_types
end
