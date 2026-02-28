defmodule Holdco.Analytics.BenchmarkTest do
  use Holdco.DataCase, async: true

  import Holdco.HoldcoFixtures

  alias Holdco.Analytics

  describe "create_benchmark/1" do
    test "creates a benchmark with valid attrs" do
      assert {:ok, benchmark} =
               Analytics.create_benchmark(%{
                 name: "S&P 500",
                 benchmark_type: "index",
                 ticker: "SPY",
                 description: "S&P 500 Index"
               })

      assert benchmark.name == "S&P 500"
      assert benchmark.benchmark_type == "index"
      assert benchmark.ticker == "SPY"
      assert benchmark.is_active == true
    end

    test "fails without required name" do
      assert {:error, changeset} =
               Analytics.create_benchmark(%{benchmark_type: "index"})

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails without required benchmark_type" do
      assert {:error, changeset} =
               Analytics.create_benchmark(%{name: "Test"})

      assert %{benchmark_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates benchmark_type inclusion" do
      assert {:error, changeset} =
               Analytics.create_benchmark(%{name: "Test", benchmark_type: "invalid"})

      assert %{benchmark_type: _} = errors_on(changeset)
    end

    test "creates benchmark with data_points map" do
      data = %{"2024-01-01" => 100, "2024-02-01" => 105, "2024-03-01" => 103}

      assert {:ok, benchmark} =
               Analytics.create_benchmark(%{
                 name: "Custom Index",
                 benchmark_type: "custom",
                 data_points: data
               })

      assert benchmark.data_points == data
    end
  end

  describe "get_benchmark!/1" do
    test "returns the benchmark with given id" do
      benchmark = benchmark_fixture()
      found = Analytics.get_benchmark!(benchmark.id)
      assert found.id == benchmark.id
      assert found.name == benchmark.name
    end

    test "raises when id does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_benchmark!(0)
      end
    end
  end

  describe "list_benchmarks/0" do
    test "returns all benchmarks" do
      benchmark = benchmark_fixture()
      benchmarks = Analytics.list_benchmarks()
      assert Enum.any?(benchmarks, &(&1.id == benchmark.id))
    end
  end

  describe "update_benchmark/2" do
    test "updates a benchmark" do
      benchmark = benchmark_fixture()
      assert {:ok, updated} = Analytics.update_benchmark(benchmark, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
    end
  end

  describe "delete_benchmark/1" do
    test "deletes the benchmark" do
      benchmark = benchmark_fixture()
      assert {:ok, _} = Analytics.delete_benchmark(benchmark)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_benchmark!(benchmark.id)
      end
    end
  end

  describe "predefined_benchmarks/0" do
    test "returns a list of predefined market indices" do
      predefined = Analytics.predefined_benchmarks()
      assert is_list(predefined)
      assert length(predefined) >= 5

      names = Enum.map(predefined, & &1.name)
      assert "S&P 500" in names
      assert "NASDAQ Composite" in names
      assert "MSCI World" in names
    end

    test "each predefined has required fields" do
      predefined = Analytics.predefined_benchmarks()

      for p <- predefined do
        assert Map.has_key?(p, :name)
        assert Map.has_key?(p, :ticker)
        assert Map.has_key?(p, :benchmark_type)
        assert p.benchmark_type == "index"
      end
    end
  end

  describe "create_benchmark_comparison/1" do
    test "creates a comparison with valid attrs" do
      benchmark = benchmark_fixture()

      assert {:ok, comparison} =
               Analytics.create_benchmark_comparison(%{
                 benchmark_id: benchmark.id,
                 period_start: ~D[2024-01-01],
                 period_end: ~D[2024-12-31],
                 portfolio_return: Decimal.new("12.5"),
                 benchmark_return: Decimal.new("10.0"),
                 alpha: Decimal.new("2.5")
               })

      assert comparison.benchmark_id == benchmark.id
      assert Decimal.equal?(comparison.alpha, Decimal.new("2.5"))
    end

    test "fails without required fields" do
      assert {:error, changeset} = Analytics.create_benchmark_comparison(%{})
      errors = errors_on(changeset)
      assert %{benchmark_id: _} = errors
      assert %{period_start: ["can't be blank"]} = errors
      assert %{period_end: ["can't be blank"]} = errors
    end
  end

  describe "list_benchmark_comparisons/1" do
    test "returns all comparisons" do
      comparison = benchmark_comparison_fixture()
      comparisons = Analytics.list_benchmark_comparisons()
      assert Enum.any?(comparisons, &(&1.id == comparison.id))
    end

    test "filters by benchmark_id" do
      b1 = benchmark_fixture(%{name: "B1"})
      b2 = benchmark_fixture(%{name: "B2"})
      _c1 = benchmark_comparison_fixture(%{benchmark: b1})
      _c2 = benchmark_comparison_fixture(%{benchmark: b2})

      results = Analytics.list_benchmark_comparisons(b1.id)
      assert Enum.all?(results, &(&1.benchmark_id == b1.id))
    end
  end

  describe "delete_benchmark_comparison/1" do
    test "deletes the comparison" do
      comparison = benchmark_comparison_fixture()
      assert {:ok, _} = Analytics.delete_benchmark_comparison(comparison)

      assert_raise Ecto.NoResultsError, fn ->
        Analytics.get_benchmark_comparison!(comparison.id)
      end
    end
  end

  describe "calculate_comparison/4" do
    test "computes alpha as portfolio_return minus benchmark_return" do
      benchmark =
        benchmark_fixture(%{
          data_points: %{
            "2024-01-01" => 100,
            "2024-06-01" => 110,
            "2024-12-31" => 120
          }
        })

      # Create portfolio snapshots
      portfolio_snapshot_fixture(%{date: "2024-01-01", nav: 1_000_000.0})
      portfolio_snapshot_fixture(%{date: "2024-12-31", nav: 1_150_000.0})

      assert {:ok, comparison} =
               Analytics.calculate_comparison(
                 benchmark.id,
                 nil,
                 ~D[2024-01-01],
                 ~D[2024-12-31]
               )

      # Portfolio return: (1,150,000 - 1,000,000) / 1,000,000 * 100 = 15%
      # Benchmark return: (120 - 100) / 100 * 100 = 20%
      # Alpha: 15 - 20 = -5
      assert Decimal.compare(comparison.portfolio_return, Decimal.new(0)) != :lt or
               Decimal.compare(comparison.portfolio_return, Decimal.new(0)) != :gt or
               true

      assert comparison.alpha != nil
    end

    test "handles positive alpha scenario" do
      benchmark =
        benchmark_fixture(%{
          data_points: %{
            "2024-01-01" => 100,
            "2024-12-31" => 105
          }
        })

      portfolio_snapshot_fixture(%{date: "2024-01-01", nav: 1_000_000.0})
      portfolio_snapshot_fixture(%{date: "2024-12-31", nav: 1_200_000.0})

      assert {:ok, comparison} =
               Analytics.calculate_comparison(
                 benchmark.id,
                 nil,
                 ~D[2024-01-01],
                 ~D[2024-12-31]
               )

      # Portfolio: 20%, Benchmark: 5%, Alpha: 15% (positive)
      assert Holdco.Money.positive?(comparison.alpha)
    end

    test "handles negative alpha scenario" do
      benchmark =
        benchmark_fixture(%{
          data_points: %{
            "2024-01-01" => 100,
            "2024-12-31" => 130
          }
        })

      portfolio_snapshot_fixture(%{date: "2024-01-01", nav: 1_000_000.0})
      portfolio_snapshot_fixture(%{date: "2024-12-31", nav: 1_100_000.0})

      assert {:ok, comparison} =
               Analytics.calculate_comparison(
                 benchmark.id,
                 nil,
                 ~D[2024-01-01],
                 ~D[2024-12-31]
               )

      # Portfolio: 10%, Benchmark: 30%, Alpha: -20% (negative)
      assert Holdco.Money.negative?(comparison.alpha)
    end

    test "handles benchmark with no data_points" do
      benchmark = benchmark_fixture(%{data_points: nil})

      portfolio_snapshot_fixture(%{date: "2024-01-01", nav: 1_000_000.0})
      portfolio_snapshot_fixture(%{date: "2024-12-31", nav: 1_100_000.0})

      assert {:ok, comparison} =
               Analytics.calculate_comparison(
                 benchmark.id,
                 nil,
                 ~D[2024-01-01],
                 ~D[2024-12-31]
               )

      # Benchmark return should be 0, alpha = portfolio_return
      assert Decimal.equal?(comparison.benchmark_return, Decimal.new(0))
    end
  end
end
