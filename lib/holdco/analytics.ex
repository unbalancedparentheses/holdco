defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{Kpi, KpiSnapshot, ReportTemplate, Anomaly, Benchmark, BenchmarkComparison}

  # KPIs
  def list_kpis(company_id \\ nil) do
    query = from(k in Kpi, order_by: k.name, preload: [:company, :snapshots])
    query = if company_id, do: where(query, [k], k.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_kpi!(id), do: Repo.get!(Kpi, id) |> Repo.preload([:company, :snapshots])

  def create_kpi(attrs) do
    %Kpi{}
    |> Kpi.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("kpis", "create")
  end

  def update_kpi(%Kpi{} = kpi, attrs) do
    kpi
    |> Kpi.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("kpis", "update")
  end

  def delete_kpi(%Kpi{} = kpi) do
    Repo.delete(kpi)
    |> audit_and_broadcast("kpis", "delete")
  end

  # KPI Snapshots
  def list_kpi_snapshots(kpi_id) do
    from(s in KpiSnapshot, where: s.kpi_id == ^kpi_id, order_by: [desc: s.date])
    |> Repo.all()
  end

  def create_kpi_snapshot(attrs) do
    %KpiSnapshot{}
    |> KpiSnapshot.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("kpi_snapshots", "create")
  end

  def delete_kpi_snapshot(%KpiSnapshot{} = snap) do
    Repo.delete(snap)
    |> audit_and_broadcast("kpi_snapshots", "delete")
  end

  # Report Templates
  def list_report_templates(user_id \\ nil) do
    query = from(rt in ReportTemplate, order_by: [desc: rt.updated_at])
    query = if user_id, do: where(query, [rt], rt.user_id == ^user_id), else: query
    Repo.all(query)
  end

  def get_report_template!(id), do: Repo.get!(ReportTemplate, id)

  def create_report_template(attrs) do
    %ReportTemplate{}
    |> ReportTemplate.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("report_templates", "create")
  end

  def update_report_template(%ReportTemplate{} = rt, attrs) do
    rt
    |> ReportTemplate.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("report_templates", "update")
  end

  def delete_report_template(%ReportTemplate{} = rt) do
    Repo.delete(rt)
    |> audit_and_broadcast("report_templates", "delete")
  end

  # KPI Auto-Population
  def compute_kpi_value(kpi) do
    case kpi.data_source do
      nil -> nil
      "" -> nil
      "revenue" ->
        financials = Holdco.Finance.list_financials(kpi.company_id)
        case financials do
          [latest | _] -> latest.revenue
          _ -> nil
        end
      "expenses" ->
        financials = Holdco.Finance.list_financials(kpi.company_id)
        case financials do
          [latest | _] -> latest.expenses
          _ -> nil
        end
      "net_income" ->
        financials = Holdco.Finance.list_financials(kpi.company_id)
        case financials do
          [latest | _] -> Money.sub(Money.to_decimal(latest.revenue), Money.to_decimal(latest.expenses))
          _ -> nil
        end
      "cash_balance" ->
        accounts = Holdco.Banking.list_bank_accounts()
        accounts
        |> Enum.filter(fn ba -> kpi.company_id == nil or ba.company_id == kpi.company_id end)
        |> Enum.reduce(Decimal.new(0), fn ba, acc -> Money.add(acc, Money.to_decimal(ba.balance)) end)
      "nav" ->
        nav = Holdco.Portfolio.calculate_nav()
        nav.nav
      "liability_total" ->
        liabilities = Holdco.Finance.list_liabilities(kpi.company_id)
        Enum.reduce(liabilities, Decimal.new(0), fn l, acc ->
          if l.status == "active", do: Money.add(acc, Money.to_decimal(l.principal)), else: acc
        end)
      _ -> nil
    end
  end

  def auto_snapshot_kpis do
    list_kpis()
    |> Enum.filter(& &1.data_source)
    |> Enum.filter(& &1.data_source != "")
    |> Enum.each(fn kpi ->
      case compute_kpi_value(kpi) do
        nil -> :skip
        value ->
          create_kpi_snapshot(%{
            "kpi_id" => kpi.id,
            "value" => value,
            "date" => Date.to_iso8601(Date.utc_today())
          })
      end
    end)
  end

  # ── Anomalies CRUD ────────────────────────────────────

  def list_anomalies(opts \\ []) do
    query = from(a in Anomaly, order_by: [desc: a.inserted_at], preload: [:company, :resolved_by])

    query =
      Enum.reduce(opts, query, fn
        {:company_id, id}, q when not is_nil(id) -> where(q, [a], a.company_id == ^id)
        {:status, s}, q when not is_nil(s) and s != "" -> where(q, [a], a.status == ^s)
        {:severity, s}, q when not is_nil(s) and s != "" -> where(q, [a], a.severity == ^s)
        {:anomaly_type, t}, q when not is_nil(t) and t != "" -> where(q, [a], a.anomaly_type == ^t)
        {:entity_type, t}, q when not is_nil(t) and t != "" -> where(q, [a], a.entity_type == ^t)
        _, q -> q
      end)

    Repo.all(query)
  end

  def get_anomaly!(id), do: Repo.get!(Anomaly, id) |> Repo.preload([:company, :resolved_by])

  def create_anomaly(attrs) do
    %Anomaly{}
    |> Anomaly.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("anomalies", "create")
  end

  def update_anomaly(%Anomaly{} = anomaly, attrs) do
    anomaly
    |> Anomaly.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("anomalies", "update")
  end

  def resolve_anomaly(%Anomaly{} = anomaly, user_id, notes \\ nil) do
    attrs = %{
      status: "resolved",
      resolved_at: DateTime.truncate(DateTime.utc_now(), :second),
      resolved_by_id: user_id,
      notes: notes || anomaly.notes
    }

    update_anomaly(anomaly, attrs)
  end

  def mark_false_positive(%Anomaly{} = anomaly, user_id, notes \\ nil) do
    attrs = %{
      status: "false_positive",
      resolved_at: DateTime.truncate(DateTime.utc_now(), :second),
      resolved_by_id: user_id,
      notes: notes || anomaly.notes
    }

    update_anomaly(anomaly, attrs)
  end

  def count_open_anomalies do
    from(a in Anomaly, where: a.status == "open", select: count(a.id))
    |> Repo.one()
  end

  # ── Anomaly Detection Engine ─────────────────────────

  def detect_transaction_anomalies(company_id \\ nil) do
    filters = if company_id, do: %{company_id: company_id}, else: %{}
    transactions = Holdco.Banking.list_transactions(filters)

    if transactions == [] do
      []
    else
      outliers = detect_outliers(transactions, company_id)
      duplicates = detect_duplicates(transactions, company_id)
      unusual_amounts = detect_unusual_amounts(transactions, company_id)

      all = outliers ++ duplicates ++ unusual_amounts
      Enum.map(all, fn attrs -> create_anomaly(attrs) end)
    end
  end

  defp detect_outliers(transactions, company_id) do
    amounts = Enum.map(transactions, fn t -> Money.to_float(t.amount) end)
    n = length(amounts)

    if n < 3 do
      []
    else
      mean = Enum.sum(amounts) / n
      variance = Enum.reduce(amounts, 0.0, fn a, acc -> acc + (a - mean) * (a - mean) end) / n
      stddev = :math.sqrt(variance)

      if stddev == 0.0 do
        []
      else
        transactions
        |> Enum.filter(fn t ->
          val = Money.to_float(t.amount)
          abs(val - mean) > 3 * stddev
        end)
        |> Enum.map(fn t ->
          val = Money.to_float(t.amount)
          deviation = if mean != 0.0, do: abs(val - mean) / abs(mean) * 100, else: 0.0

          %{
            company_id: company_id || t.company_id,
            entity_type: "transaction",
            entity_id: t.id,
            anomaly_type: "outlier",
            severity: if(abs(val - mean) > 5 * stddev, do: "critical", else: "high"),
            description: "Transaction amount #{Money.format(t.amount)} is > 3 standard deviations from mean #{Money.format(mean)}",
            detected_value: t.amount,
            expected_range_low: Decimal.from_float(mean - 3 * stddev),
            expected_range_high: Decimal.from_float(mean + 3 * stddev),
            deviation_pct: Decimal.from_float(deviation)
          }
        end)
      end
    end
  end

  defp detect_duplicates(transactions, company_id) do
    transactions
    |> Enum.group_by(fn t -> {t.date, t.description} end)
    |> Enum.filter(fn {_key, group} -> length(group) > 1 end)
    |> Enum.flat_map(fn {{date, desc}, group} ->
      # Skip the first one, flag the rest as duplicates
      group
      |> Enum.drop(1)
      |> Enum.map(fn t ->
        %{
          company_id: company_id || t.company_id,
          entity_type: "transaction",
          entity_id: t.id,
          anomaly_type: "duplicate",
          severity: "medium",
          description: "Possible duplicate: '#{desc}' on #{date} appears #{length(group)} times",
          detected_value: t.amount
        }
      end)
    end)
  end

  defp detect_unusual_amounts(transactions, company_id) do
    amounts = Enum.map(transactions, fn t -> Money.to_float(t.amount) end) |> Enum.sort()
    n = length(amounts)

    if n < 3 do
      []
    else
      median_idx = div(n, 2)
      median = Enum.at(amounts, median_idx)

      if median == 0.0 do
        []
      else
        transactions
        |> Enum.filter(fn t ->
          val = Money.to_float(t.amount)
          val > median * 10
        end)
        |> Enum.map(fn t ->
          val = Money.to_float(t.amount)
          ratio = val / median

          %{
            company_id: company_id || t.company_id,
            entity_type: "transaction",
            entity_id: t.id,
            anomaly_type: "unusual_amount",
            severity: if(ratio > 50, do: "critical", else: "high"),
            description: "Transaction amount #{Money.format(t.amount)} is #{Float.round(ratio, 1)}x the median (#{Money.format(median)})",
            detected_value: t.amount,
            deviation_pct: Decimal.from_float(ratio * 100)
          }
        end)
      end
    end
  end

  def detect_financial_anomalies(company_id \\ nil) do
    financials = Holdco.Finance.list_financials(company_id)

    if length(financials) < 2 do
      []
    else
      # Financials come ordered desc by period, reverse for chronological
      sorted = Enum.reverse(financials)
      pairs = Enum.zip(sorted, tl(sorted))

      rapid_changes =
        Enum.flat_map(pairs, fn {prev, curr} ->
          anomalies = []

          # Check revenue rapid change
          prev_rev = Money.to_float(prev.revenue)
          curr_rev = Money.to_float(curr.revenue)

          anomalies =
            if prev_rev != 0.0 do
              change_pct = (curr_rev - prev_rev) / abs(prev_rev) * 100

              if abs(change_pct) > 50 do
                [
                  %{
                    company_id: company_id || curr.company_id,
                    entity_type: "financial",
                    entity_id: curr.id,
                    anomaly_type: "rapid_change",
                    severity: if(abs(change_pct) > 100, do: "critical", else: "high"),
                    description: "Revenue changed #{Float.round(change_pct, 1)}% from #{prev.period} to #{curr.period}",
                    detected_value: curr.revenue,
                    expected_range_low: Money.mult(prev.revenue, Decimal.from_float(0.5)),
                    expected_range_high: Money.mult(prev.revenue, Decimal.from_float(1.5)),
                    deviation_pct: Decimal.from_float(abs(change_pct))
                  }
                  | anomalies
                ]
              else
                anomalies
              end
            else
              anomalies
            end

          # Check expense rapid change
          prev_exp = Money.to_float(prev.expenses)
          curr_exp = Money.to_float(curr.expenses)

          anomalies =
            if prev_exp != 0.0 do
              change_pct = (curr_exp - prev_exp) / abs(prev_exp) * 100

              if abs(change_pct) > 50 do
                [
                  %{
                    company_id: company_id || curr.company_id,
                    entity_type: "financial",
                    entity_id: curr.id,
                    anomaly_type: "rapid_change",
                    severity: if(abs(change_pct) > 100, do: "critical", else: "high"),
                    description: "Expenses changed #{Float.round(change_pct, 1)}% from #{prev.period} to #{curr.period}",
                    detected_value: curr.expenses,
                    expected_range_low: Money.mult(prev.expenses, Decimal.from_float(0.5)),
                    expected_range_high: Money.mult(prev.expenses, Decimal.from_float(1.5)),
                    deviation_pct: Decimal.from_float(abs(change_pct))
                  }
                  | anomalies
                ]
              else
                anomalies
              end
            else
              anomalies
            end

          # Check for negative revenue
          anomalies =
            if Money.negative?(curr.revenue) do
              [
                %{
                  company_id: company_id || curr.company_id,
                  entity_type: "financial",
                  entity_id: curr.id,
                  anomaly_type: "rapid_change",
                  severity: "critical",
                  description: "Negative revenue (#{Money.format(curr.revenue)}) in period #{curr.period}",
                  detected_value: curr.revenue,
                  expected_range_low: Decimal.new(0),
                  expected_range_high: nil
                }
                | anomalies
              ]
            else
              anomalies
            end

          anomalies
        end)

      Enum.map(rapid_changes, fn attrs -> create_anomaly(attrs) end)
    end
  end

  # ── Benchmarks CRUD ──────────────────────────────────

  def list_benchmarks do
    from(b in Benchmark, order_by: b.name, preload: [:comparisons])
    |> Repo.all()
  end

  def get_benchmark!(id), do: Repo.get!(Benchmark, id) |> Repo.preload([:comparisons])

  def create_benchmark(attrs) do
    %Benchmark{}
    |> Benchmark.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("benchmarks", "create")
  end

  def update_benchmark(%Benchmark{} = benchmark, attrs) do
    benchmark
    |> Benchmark.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("benchmarks", "update")
  end

  def delete_benchmark(%Benchmark{} = benchmark) do
    Repo.delete(benchmark)
    |> audit_and_broadcast("benchmarks", "delete")
  end

  def predefined_benchmarks do
    [
      %{name: "S&P 500", ticker: "SPY", benchmark_type: "index", description: "S&P 500 Index"},
      %{name: "NASDAQ Composite", ticker: "QQQ", benchmark_type: "index", description: "NASDAQ Composite Index"},
      %{name: "MSCI World", ticker: "URTH", benchmark_type: "index", description: "MSCI World Index"},
      %{name: "Russell 2000", ticker: "IWM", benchmark_type: "index", description: "Russell 2000 Small Cap Index"},
      %{name: "Bloomberg US Agg Bond", ticker: "AGG", benchmark_type: "index", description: "Bloomberg US Aggregate Bond Index"},
      %{name: "MSCI Emerging Markets", ticker: "EEM", benchmark_type: "index", description: "MSCI Emerging Markets Index"}
    ]
  end

  # ── Benchmark Comparisons ────────────────────────────

  def list_benchmark_comparisons(benchmark_id \\ nil) do
    query = from(bc in BenchmarkComparison, order_by: [desc: bc.period_end], preload: [:benchmark, :company])

    query =
      if benchmark_id,
        do: where(query, [bc], bc.benchmark_id == ^benchmark_id),
        else: query

    Repo.all(query)
  end

  def get_benchmark_comparison!(id),
    do: Repo.get!(BenchmarkComparison, id) |> Repo.preload([:benchmark, :company])

  def create_benchmark_comparison(attrs) do
    %BenchmarkComparison{}
    |> BenchmarkComparison.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("benchmark_comparisons", "create")
  end

  def delete_benchmark_comparison(%BenchmarkComparison{} = comparison) do
    Repo.delete(comparison)
    |> audit_and_broadcast("benchmark_comparisons", "delete")
  end

  def calculate_comparison(benchmark_id, company_id, period_start, period_end) do
    benchmark = get_benchmark!(benchmark_id)

    # Calculate portfolio return from snapshots
    snapshots = Holdco.Assets.list_portfolio_snapshots()

    period_start_str = to_string(period_start)
    period_end_str = to_string(period_end)

    relevant_snapshots =
      snapshots
      |> Enum.filter(fn s -> s.date >= period_start_str and s.date <= period_end_str end)
      |> Enum.sort_by(& &1.date)

    portfolio_return =
      case relevant_snapshots do
        [first | _] = snaps ->
          last = List.last(snaps)
          start_nav = Money.to_float(first.nav)
          end_nav = Money.to_float(last.nav)

          if start_nav != 0.0 do
            Decimal.from_float((end_nav - start_nav) / start_nav * 100)
          else
            Decimal.new(0)
          end

        _ ->
          Decimal.new(0)
      end

    # Calculate benchmark return from data points
    benchmark_return =
      case benchmark.data_points do
        nil ->
          Decimal.new(0)

        data_points when is_map(data_points) ->
          sorted_points =
            data_points
            |> Enum.filter(fn {date, _val} -> date >= period_start_str and date <= period_end_str end)
            |> Enum.sort_by(fn {date, _val} -> date end)

          case sorted_points do
            [{_, start_val} | _] = points ->
              {_, end_val} = List.last(points)
              sv = Money.to_float(start_val)
              ev = Money.to_float(end_val)

              if sv != 0.0 do
                Decimal.from_float((ev - sv) / sv * 100)
              else
                Decimal.new(0)
              end

            _ ->
              Decimal.new(0)
          end
      end

    alpha = Money.sub(portfolio_return, benchmark_return)

    create_benchmark_comparison(%{
      benchmark_id: benchmark_id,
      company_id: company_id,
      period_start: period_start,
      period_end: period_end,
      portfolio_return: portfolio_return,
      benchmark_return: benchmark_return,
      alpha: alpha
    })
  end

  # PubSub
  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "analytics")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "analytics", message)

  defp audit_and_broadcast(result, table, action) do
    case result do
      {:ok, record} ->
        Holdco.Platform.log_action(action, table, record.id)
        broadcast({String.to_atom("#{table}_#{action}d"), record})
        {:ok, record}

      error ->
        error
    end
  end
end
