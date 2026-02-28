defmodule HoldcoWeb.BenchmarkLiveIndexTest do
  use HoldcoWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Holdco.HoldcoFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "renders Benchmarks page", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Benchmarks"
      assert html =~ "Compare portfolio performance against market indices"
    end

    test "shows metrics strip", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Active Benchmarks"
      assert html =~ "Total Comparisons"
      assert html =~ "Predefined Available"
    end

    test "shows benchmarks table with headers", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Name"
      assert html =~ "Type"
      assert html =~ "Ticker"
      assert html =~ "Active"
    end

    test "shows empty state when no benchmarks", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "No benchmarks configured yet"
    end

    test "shows predefined indices section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Predefined Indices"
    end

    test "shows comparison history section", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Comparison History"
    end

    test "shows empty state for comparisons", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/benchmarks")
      assert html =~ "No comparisons yet"
    end

    test "opens add benchmark form", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/benchmarks")
      html = render_click(live, "show_form")
      assert html =~ "Add Custom Benchmark"
      assert html =~ "Add Benchmark"
    end
  end

  describe "close_form" do
    test "closes the add benchmark form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      render_click(view, "show_form")
      html = render_click(view, "close_form")
      refute html =~ "Add Custom Benchmark"
    end
  end

  describe "show_comparison_form / close_comparison_form" do
    test "opens comparison form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      html = render_click(view, "show_comparison_form")
      assert html =~ "Calculate Comparison"
    end

    test "closes comparison form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      render_click(view, "show_comparison_form")
      html = render_click(view, "close_comparison_form")
      refute html =~ "Calculate Comparison"
    end
  end

  describe "save (create benchmark)" do
    test "creates a benchmark with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "benchmark" => %{
            "name" => "S&P 500 Test",
            "benchmark_type" => "index",
            "ticker" => "SPY",
            "description" => "Standard and Poor's 500"
          }
        })

      assert html =~ "Benchmark created"
    end

    test "shows error when creating benchmark with missing fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      render_click(view, "show_form")

      html =
        render_click(view, "save", %{
          "benchmark" => %{
            "name" => "",
            "benchmark_type" => ""
          }
        })

      assert html =~ "Failed to create benchmark"
    end
  end

  describe "delete (benchmark)" do
    test "deletes a benchmark", %{conn: conn} do
      benchmark = benchmark_fixture(%{name: "Delete Me Benchmark"})

      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      assert render(view) =~ "Delete Me Benchmark"

      html = render_click(view, "delete", %{"id" => to_string(benchmark.id)})
      assert html =~ "Benchmark deleted"
      refute html =~ "Delete Me Benchmark"
    end
  end

  describe "add_predefined" do
    test "adds a predefined benchmark", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/benchmarks")

      html = render_click(view, "add_predefined", %{"index" => "0"})
      assert html =~ "added"
    end
  end

  describe "calculate_comparison" do
    test "calculates a benchmark comparison", %{conn: conn} do
      benchmark = benchmark_fixture(%{name: "Test Benchmark"})

      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      render_click(view, "show_comparison_form")

      html =
        render_click(view, "calculate_comparison", %{
          "comparison" => %{
            "benchmark_id" => to_string(benchmark.id),
            "company_id" => "",
            "period_start" => "2024-01-01",
            "period_end" => "2024-12-31"
          }
        })

      assert html =~ "Comparison calculated"
    end
  end

  describe "delete_comparison" do
    test "deletes a benchmark comparison", %{conn: conn} do
      benchmark = benchmark_fixture()
      comparison = benchmark_comparison_fixture(%{benchmark: benchmark})

      {:ok, view, _html} = live(conn, ~p"/benchmarks")
      html = render_click(view, "delete_comparison", %{"id" => to_string(comparison.id)})
      assert html =~ "Comparison deleted"
    end
  end

  describe "displays existing data" do
    test "shows benchmark in table", %{conn: conn} do
      benchmark_fixture(%{name: "My Test Index", benchmark_type: "index", ticker: "QQQ"})

      {:ok, _view, html} = live(conn, ~p"/benchmarks")
      assert html =~ "My Test Index"
      assert html =~ "QQQ"
      assert html =~ "index"
    end

    test "shows comparison in history table", %{conn: conn} do
      benchmark = benchmark_fixture(%{name: "Comparison Benchmark"})
      benchmark_comparison_fixture(%{benchmark: benchmark})

      {:ok, _view, html} = live(conn, ~p"/benchmarks")
      assert html =~ "Comparison Benchmark"
    end
  end
end
