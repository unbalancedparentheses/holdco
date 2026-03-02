defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{ReportTemplate, ScheduledReport, StressTest, LiquidityCoverage, Anomaly, Benchmark, BenchmarkComparison, CounterpartyExposure, LoanCovenant, Airdrop, CustomDashboard, BiConnector, BiExportLog, HealthScore}

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

  # Scheduled Reports
  def list_scheduled_reports(company_id \\ nil) do
    query = from(sr in ScheduledReport, order_by: [desc: sr.updated_at], preload: [:company])
    query = if company_id, do: where(query, [sr], sr.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_scheduled_report!(id), do: Repo.get!(ScheduledReport, id) |> Repo.preload([:company])

  def create_scheduled_report(attrs) do
    %ScheduledReport{}
    |> ScheduledReport.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("scheduled_reports", "create")
  end

  def update_scheduled_report(%ScheduledReport{} = report, attrs) do
    report
    |> ScheduledReport.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("scheduled_reports", "update")
  end

  def delete_scheduled_report(%ScheduledReport{} = report) do
    Repo.delete(report)
    |> audit_and_broadcast("scheduled_reports", "delete")
  end

  def list_due_scheduled_reports do
    today = Date.to_iso8601(Date.utc_today())

    from(sr in ScheduledReport,
      where: sr.is_active == true,
      where: sr.next_run_date <= ^today or is_nil(sr.next_run_date),
      preload: [:company]
    )
    |> Repo.all()
  end

  def advance_next_run_date(%ScheduledReport{} = report) do
    next_date = compute_next_run_date(report.frequency, Date.utc_today())

    update_scheduled_report(report, %{
      next_run_date: Date.to_iso8601(next_date),
      last_sent_at: DateTime.utc_now() |> DateTime.truncate(:second)
    })
  end

  defp compute_next_run_date("daily", from_date), do: Date.add(from_date, 1)
  defp compute_next_run_date("weekly", from_date), do: Date.add(from_date, 7)

  defp compute_next_run_date("monthly", from_date) do
    {year, month, _day} = Date.to_erl(from_date)

    {new_year, new_month} =
      if month == 12, do: {year + 1, 1}, else: {year, month + 1}

    day = min(Date.days_in_month(Date.new!(new_year, new_month, 1)), elem(Date.to_erl(from_date), 2))
    Date.new!(new_year, new_month, day)
  end

  defp compute_next_run_date("quarterly", from_date) do
    from_date
    |> then(&compute_next_run_date("monthly", &1))
    |> then(&compute_next_run_date("monthly", &1))
    |> then(&compute_next_run_date("monthly", &1))
  end

  defp compute_next_run_date(_, from_date), do: Date.add(from_date, 1)

  # ── Stress Tests ─────────────────────────────────────

  def list_stress_tests(company_id \\ nil) do
    query = from(st in StressTest, order_by: [desc: st.inserted_at], preload: [:company, :created_by])
    query = if company_id, do: where(query, [st], st.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_stress_test!(id), do: Repo.get!(StressTest, id) |> Repo.preload([:company, :created_by])

  def create_stress_test(attrs) do
    %StressTest{}
    |> StressTest.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("stress_tests", "create")
  end

  def update_stress_test(%StressTest{} = st, attrs) do
    st
    |> StressTest.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("stress_tests", "update")
  end

  def delete_stress_test(%StressTest{} = st) do
    Repo.delete(st)
    |> audit_and_broadcast("stress_tests", "delete")
  end

  @doc """
  Execute a stress test: apply shocks to the current portfolio and compute
  original NAV, stressed NAV, dollar impact, percentage impact, and per-holding detail.
  """
  def run_stress_test(%StressTest{} = stress_test) do
    # Mark as running
    {:ok, stress_test} = update_stress_test(stress_test, %{status: "running"})

    try do
      nav_data = Holdco.Portfolio.calculate_nav()
      holdings = Holdco.Assets.list_holdings()
      original_nav = nav_data.nav
      shocks = stress_test.shocks || %{}

      per_holding =
        Enum.map(holdings, fn holding ->
          current_value = Holdco.Portfolio.holding_value(holding)
          shock_pct = find_applicable_shock(holding, shocks)
          stressed_value = Money.add(current_value, Money.mult(current_value, shock_pct))
          impact = Money.sub(stressed_value, current_value)

          %{
            "holding_id" => holding.id,
            "asset" => holding.asset,
            "ticker" => holding.ticker,
            "asset_type" => holding.asset_type,
            "currency" => holding.currency,
            "original_value" => Decimal.to_string(current_value),
            "stressed_value" => Decimal.to_string(stressed_value),
            "impact" => Decimal.to_string(impact),
            "shock_applied" => Decimal.to_string(Money.to_decimal(shock_pct))
          }
        end)

      total_impact =
        Enum.reduce(per_holding, Decimal.new(0), fn h, acc ->
          Money.add(acc, Money.to_decimal(h["impact"]))
        end)

      stressed_nav = Money.add(original_nav, total_impact)

      impact_pct =
        if Money.zero?(original_nav),
          do: Decimal.new(0),
          else: Money.mult(Money.div(total_impact, original_nav), 100)

      results = %{
        "original_nav" => Decimal.to_string(original_nav),
        "stressed_nav" => Decimal.to_string(stressed_nav),
        "impact" => Decimal.to_string(total_impact),
        "impact_pct" => Decimal.to_string(impact_pct),
        "per_holding" => per_holding
      }

      update_stress_test(stress_test, %{
        status: "completed",
        results: results,
        run_at: DateTime.truncate(DateTime.utc_now(), :second)
      })
    rescue
      e ->
        update_stress_test(stress_test, %{status: "failed", results: %{"error" => Exception.message(e)}})
    end
  end

  # Find the most specific applicable shock for a holding.
  # Priority: ticker match > asset_type match > FX-pair match
  defp find_applicable_shock(holding, shocks) do
    ticker = holding.ticker || ""
    asset_type = holding.asset_type || ""
    currency = holding.currency || "USD"

    cond do
      # Direct ticker match (e.g. "BTC" => -0.40)
      Map.has_key?(shocks, ticker) and ticker != "" ->
        Money.to_decimal(shocks[ticker])

      # Asset type match (e.g. "equity" => -0.20, "crypto" => -0.40)
      Map.has_key?(shocks, asset_type) ->
        Money.to_decimal(shocks[asset_type])

      # FX pair match (e.g. "EUR/USD" => -0.10 applies to EUR-denominated holdings)
      true ->
        fx_key = "#{currency}/USD"

        if Map.has_key?(shocks, fx_key) do
          Money.to_decimal(shocks[fx_key])
        else
          Decimal.new(0)
        end
    end
  end

  @doc "Return a list of predefined stress test scenario templates."
  def predefined_scenarios do
    [
      %{name: "Crypto Crash", shocks: %{"crypto" => -0.40}},
      %{name: "Equity Bear Market", shocks: %{"equity" => -0.20}},
      %{name: "USD Strengthening", shocks: %{"EUR/USD" => -0.10, "GBP/USD" => -0.10, "BRL/USD" => -0.15}},
      %{name: "Global Recession", shocks: %{"equity" => -0.30, "crypto" => -0.50, "real_estate" => -0.15}},
      %{name: "Interest Rate Shock", shocks: %{"fixed_income" => -0.08, "real_estate" => -0.10}}
    ]
  end

  # ── Liquidity Coverage ─────────────────────────────────

  def list_liquidity_coverages(company_id \\ nil) do
    query = from(lc in LiquidityCoverage, order_by: [desc: lc.calculation_date], preload: [:company])
    query = if company_id, do: where(query, [lc], lc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_liquidity_coverage!(id), do: Repo.get!(LiquidityCoverage, id) |> Repo.preload([:company])

  def create_liquidity_coverage(attrs) do
    %LiquidityCoverage{}
    |> LiquidityCoverage.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("liquidity_coverages", "create")
  end

  def update_liquidity_coverage(%LiquidityCoverage{} = lc, attrs) do
    lc
    |> LiquidityCoverage.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("liquidity_coverages", "update")
  end

  def delete_liquidity_coverage(%LiquidityCoverage{} = lc) do
    Repo.delete(lc)
    |> audit_and_broadcast("liquidity_coverages", "delete")
  end

  @doc """
  Calculate the Liquidity Coverage Ratio for a company.

  HQLA Levels:
    - Level 1: Cash (bank account balances) -- 0% haircut
    - Level 2A: Government/agency bonds (asset_type "fixed_income" or "government_bond") -- 15% haircut
    - Level 2B: Corporate bonds (asset_type "corporate_bond") -- 50% haircut

  Net cash outflows estimated as 25% of active liabilities maturing within 30 days
  (simplified: use total active liabilities as a proxy).

  LCR = (total_hqla / net_cash_outflows_30d) * 100
  Status: >= 100 adequate, 80..100 warning, < 80 critical
  """
  def calculate_lcr(company_id) do
    bank_accounts = Holdco.Banking.list_bank_accounts(%{company_id: company_id})
    holdings = Holdco.Assets.list_holdings(%{company_id: company_id})
    liabilities = Holdco.Finance.list_liabilities(company_id)

    # Level 1 HQLA: cash balances (no haircut)
    hqla_level1 =
      Enum.reduce(bank_accounts, Decimal.new(0), fn ba, acc ->
        Money.add(acc, Holdco.Portfolio.to_usd(ba.balance, ba.currency))
      end)

    # Level 2A: government/agency bonds with 15% haircut
    level2a_holdings =
      Enum.filter(holdings, fn h -> h.asset_type in ~w(fixed_income government_bond) end)

    hqla_level2a_gross =
      Enum.reduce(level2a_holdings, Decimal.new(0), fn h, acc ->
        Money.add(acc, Holdco.Portfolio.holding_value(h))
      end)

    hqla_level2a = Money.mult(hqla_level2a_gross, Decimal.from_float(0.85))

    # Level 2B: corporate bonds with 50% haircut
    level2b_holdings =
      Enum.filter(holdings, fn h -> h.asset_type in ~w(corporate_bond) end)

    hqla_level2b_gross =
      Enum.reduce(level2b_holdings, Decimal.new(0), fn h, acc ->
        Money.add(acc, Holdco.Portfolio.holding_value(h))
      end)

    hqla_level2b = Money.mult(hqla_level2b_gross, Decimal.from_float(0.50))

    total_hqla = Money.add(hqla_level1, Money.add(hqla_level2a, hqla_level2b))

    # Estimate 30-day net cash outflows: 25% of total active liabilities
    total_active_liabilities =
      liabilities
      |> Enum.filter(fn l -> l.status == "active" end)
      |> Enum.reduce(Decimal.new(0), fn l, acc ->
        Money.add(acc, Holdco.Portfolio.to_usd(l.principal, l.currency))
      end)

    net_cash_outflows_30d = Money.mult(total_active_liabilities, Decimal.from_float(0.25))

    lcr_ratio =
      if Money.zero?(net_cash_outflows_30d),
        do: Decimal.new(999),
        else: Money.mult(Money.div(total_hqla, net_cash_outflows_30d), 100)

    status =
      cond do
        Money.gte?(lcr_ratio, 100) -> "adequate"
        Money.gte?(lcr_ratio, 80) -> "warning"
        true -> "critical"
      end

    create_liquidity_coverage(%{
      company_id: company_id,
      calculation_date: Date.utc_today(),
      hqla_level1: hqla_level1,
      hqla_level2a: hqla_level2a,
      hqla_level2b: hqla_level2b,
      total_hqla: total_hqla,
      net_cash_outflows_30d: net_cash_outflows_30d,
      lcr_ratio: lcr_ratio,
      status: status
    })
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

  # Counterparty Exposures
  def list_counterparty_exposures(company_id \\ nil) do
    query = from(ce in CounterpartyExposure, order_by: ce.counterparty_name, preload: [:company])
    query = if company_id, do: where(query, [ce], ce.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_counterparty_exposure!(id), do: Repo.get!(CounterpartyExposure, id) |> Repo.preload(:company)

  def create_counterparty_exposure(attrs) do
    %CounterpartyExposure{}
    |> CounterpartyExposure.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("counterparty_exposures", "create")
  end

  def update_counterparty_exposure(%CounterpartyExposure{} = exposure, attrs) do
    exposure
    |> CounterpartyExposure.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("counterparty_exposures", "update")
  end

  def delete_counterparty_exposure(%CounterpartyExposure{} = exposure) do
    Repo.delete(exposure)
    |> audit_and_broadcast("counterparty_exposures", "delete")
  end

  @credit_rating_scores %{
    "AAA" => 5, "AA" => 10, "A" => 15, "BBB" => 25, "BB" => 40,
    "B" => 55, "CCC" => 70, "CC" => 80, "C" => 90, "D" => 100, "NR" => 50
  }

  def calculate_risk_score(%CounterpartyExposure{} = exposure) do
    # Score based on: credit rating (40%), utilization (30%), exposure amount (20%), review freshness (10%)
    # Higher score = more risky
    rating_score = Map.get(@credit_rating_scores, exposure.credit_rating, 50)
    rating_component = Money.mult(rating_score, "0.40")

    utilization = Money.to_decimal(exposure.utilization_pct)
    utilization_component = Money.mult(utilization, "0.30")

    # Exposure amount scoring: > 10M = 100, > 5M = 75, > 1M = 50, > 100K = 25, else = 10
    exposure_amt = Money.to_decimal(exposure.exposure_amount)
    exposure_raw =
      cond do
        Money.gt?(exposure_amt, "10000000") -> 100
        Money.gt?(exposure_amt, "5000000") -> 75
        Money.gt?(exposure_amt, "1000000") -> 50
        Money.gt?(exposure_amt, "100000") -> 25
        true -> 10
      end
    exposure_component = Money.mult(exposure_raw, "0.20")

    # Review freshness: overdue = 100, within 30 days = 50, fresh = 10
    review_raw =
      case exposure.next_review_date do
        nil -> 50
        date ->
          days_until = Date.diff(date, Date.utc_today())
          cond do
            days_until < 0 -> 100
            days_until <= 30 -> 50
            true -> 10
          end
      end
    review_component = Money.mult(review_raw, "0.10")

    score = Money.add(Money.add(rating_component, utilization_component), Money.add(exposure_component, review_component))
    Money.min(Money.max(score, 0), 100) |> Money.round(1)
  end

  def concentration_analysis(company_id \\ nil) do
    exposures = list_counterparty_exposures(company_id)

    total_exposure =
      Enum.reduce(exposures, Decimal.new(0), fn e, acc ->
        Money.add(acc, Money.to_decimal(e.exposure_amount))
      end)

    by_type =
      exposures
      |> Enum.group_by(& &1.counterparty_type)
      |> Enum.map(fn {type, exps} ->
        type_total = Enum.reduce(exps, Decimal.new(0), fn e, acc ->
          Money.add(acc, Money.to_decimal(e.exposure_amount))
        end)
        pct = if Money.gt?(total_exposure, 0), do: Money.mult(Money.div(type_total, total_exposure), 100), else: Decimal.new(0)
        %{
          type: type,
          total: type_total,
          count: length(exps),
          percentage: Money.round(pct, 1),
          concentrated: Money.gt?(pct, 25)
        }
      end)

    by_counterparty =
      exposures
      |> Enum.group_by(& &1.counterparty_name)
      |> Enum.map(fn {name, exps} ->
        cp_total = Enum.reduce(exps, Decimal.new(0), fn e, acc ->
          Money.add(acc, Money.to_decimal(e.exposure_amount))
        end)
        pct = if Money.gt?(total_exposure, 0), do: Money.mult(Money.div(cp_total, total_exposure), 100), else: Decimal.new(0)
        %{
          name: name,
          total: cp_total,
          count: length(exps),
          percentage: Money.round(pct, 1),
          concentrated: Money.gt?(pct, 25)
        }
      end)

    concentration_warnings =
      (Enum.filter(by_type, & &1.concentrated) |> Enum.map(fn c -> "Type '#{c.type}' at #{Money.format(c.percentage, 1)}%" end)) ++
      (Enum.filter(by_counterparty, & &1.concentrated) |> Enum.map(fn c -> "Counterparty '#{c.name}' at #{Money.format(c.percentage, 1)}%" end))

    %{
      total_exposure: total_exposure,
      by_type: by_type,
      by_counterparty: by_counterparty,
      warnings: concentration_warnings
    }
  end

  # Loan Covenants
  def list_loan_covenants(company_id \\ nil) do
    query = from(lc in LoanCovenant, order_by: lc.name, preload: [:company, :liability])
    query = if company_id, do: where(query, [lc], lc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_loan_covenant!(id), do: Repo.get!(LoanCovenant, id) |> Repo.preload([:company, :liability])

  def create_loan_covenant(attrs) do
    %LoanCovenant{}
    |> LoanCovenant.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("loan_covenants", "create")
  end

  def update_loan_covenant(%LoanCovenant{} = covenant, attrs) do
    covenant
    |> LoanCovenant.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("loan_covenants", "update")
  end

  def delete_loan_covenant(%LoanCovenant{} = covenant) do
    Repo.delete(covenant)
    |> audit_and_broadcast("loan_covenants", "delete")
  end

  def check_covenant_compliance(%LoanCovenant{} = covenant) do
    current_value = compute_covenant_metric(covenant)

    case current_value do
      nil ->
        {:compliant, nil}

      value ->
        threshold = Money.to_decimal(covenant.threshold)
        status = evaluate_covenant(covenant.comparison, value, threshold, covenant.upper_bound)
        {status, value}
    end
  end

  defp compute_covenant_metric(%LoanCovenant{} = covenant) do
    case covenant.metric do
      "debt_to_equity" ->
        bs = Holdco.Finance.balance_sheet(covenant.company_id)
        if Money.gt?(bs.total_equity, 0),
          do: Money.round(Money.div(bs.total_liabilities, bs.total_equity), 4),
          else: nil

      "current_ratio" ->
        bs = Holdco.Finance.balance_sheet(covenant.company_id)
        if Money.gt?(bs.total_liabilities, 0),
          do: Money.round(Money.div(bs.total_assets, bs.total_liabilities), 4),
          else: nil

      "interest_coverage" ->
        is = Holdco.Finance.income_statement(covenant.company_id)
        # Approximate EBITDA as net_income (simplified)
        liabilities = Holdco.Finance.list_liabilities(covenant.company_id)
        interest_expense = Enum.reduce(liabilities, Decimal.new(0), fn l, acc ->
          rate = Money.to_decimal(l.interest_rate)
          principal = Money.to_decimal(l.principal)
          Money.add(acc, Money.mult(principal, rate))
        end)
        if Money.gt?(interest_expense, 0),
          do: Money.round(Money.div(is.net_income, interest_expense), 4),
          else: nil

      "min_cash" ->
        accounts = Holdco.Banking.list_bank_accounts()
        accounts
        |> Enum.filter(fn ba -> covenant.company_id == nil or ba.company_id == covenant.company_id end)
        |> Enum.reduce(Decimal.new(0), fn ba, acc -> Money.add(acc, Money.to_decimal(ba.balance)) end)

      "max_leverage" ->
        bs = Holdco.Finance.balance_sheet(covenant.company_id)
        total_debt =
          Holdco.Finance.list_liabilities(covenant.company_id)
          |> Enum.filter(& &1.status == "active")
          |> Enum.reduce(Decimal.new(0), fn l, acc -> Money.add(acc, Money.to_decimal(l.principal)) end)
        if Money.gt?(bs.total_assets, 0),
          do: Money.round(Money.div(total_debt, bs.total_assets), 4),
          else: nil

      _ ->
        # Use current_value if set directly
        if covenant.current_value, do: Money.to_decimal(covenant.current_value), else: nil
    end
  end

  defp evaluate_covenant(comparison, value, threshold, upper_bound) do
    case comparison do
      "above" ->
        cond do
          Money.gte?(value, threshold) -> :compliant
          Money.gte?(value, Money.mult(threshold, "0.90")) -> :warning
          true -> :breached
        end

      "below" ->
        cond do
          Money.lt?(value, threshold) -> :compliant
          Money.lt?(value, Money.mult(threshold, "1.10")) -> :warning
          true -> :breached
        end

      "between" ->
        upper = Money.to_decimal(upper_bound)
        cond do
          Money.gte?(value, threshold) and Money.lt?(value, upper) -> :compliant
          Money.gte?(value, Money.mult(threshold, "0.90")) and Money.lt?(value, Money.mult(upper, "1.10")) -> :warning
          true -> :breached
        end

      _ ->
        :compliant
    end
  end

  def check_all_covenants(company_id \\ nil) do
    covenants = list_loan_covenants(company_id)

    Enum.map(covenants, fn covenant ->
      {status, current_value} = check_covenant_compliance(covenant)
      status_str = Atom.to_string(status)

      new_breach_count =
        if status == :breached,
          do: (covenant.breach_count || 0) + 1,
          else: covenant.breach_count || 0

      attrs = %{
        status: status_str,
        current_value: current_value,
        last_measured_at: DateTime.utc_now() |> DateTime.truncate(:second),
        breach_count: new_breach_count
      }

      {:ok, updated} = update_loan_covenant(covenant, attrs)
      {updated, status}
    end)
  end


  # Airdrops
  def list_airdrops(company_id \\ nil) do
    query = from(a in Airdrop, order_by: [desc: a.received_date], preload: [:company])
    query = if company_id, do: where(query, [a], a.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_airdrop!(id), do: Repo.get!(Airdrop, id) |> Repo.preload(:company)

  def create_airdrop(attrs) do
    %Airdrop{}
    |> Airdrop.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("airdrops", "create")
  end

  def update_airdrop(%Airdrop{} = airdrop, attrs) do
    airdrop
    |> Airdrop.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("airdrops", "update")
  end

  def delete_airdrop(%Airdrop{} = airdrop) do
    Repo.delete(airdrop)
    |> audit_and_broadcast("airdrops", "delete")
  end

  def unclaimed_airdrops(company_id) do
    from(a in Airdrop,
      where: a.company_id == ^company_id and a.claimed == false and a.eligible == true,
      order_by: [desc: a.received_date],
      preload: [:company]
    )
    |> Repo.all()
  end

  def airdrop_value_summary(company_id) do
    from(a in Airdrop,
      where: a.company_id == ^company_id,
      select: %{
        total_value_at_receipt: sum(a.value_at_receipt),
        total_current_value: sum(a.current_value),
        total_count: count(a.id),
        claimed_count: sum(fragment("CASE WHEN ? = true THEN 1 ELSE 0 END", a.claimed))
      }
    )
    |> Repo.one()
  end


  # ── Custom Dashboards ──────────────────────────────────────────

  def list_custom_dashboards(user_id) do
    from(d in CustomDashboard, where: d.user_id == ^user_id, order_by: [desc: d.updated_at])
    |> Repo.all()
  end

  def get_custom_dashboard!(id), do: Repo.get!(CustomDashboard, id)

  def create_custom_dashboard(attrs) do
    %CustomDashboard{}
    |> CustomDashboard.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("custom_dashboards", "create")
  end

  def update_custom_dashboard(%CustomDashboard{} = dashboard, attrs) do
    dashboard
    |> CustomDashboard.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("custom_dashboards", "update")
  end

  def delete_custom_dashboard(%CustomDashboard{} = dashboard) do
    Repo.delete(dashboard)
    |> audit_and_broadcast("custom_dashboards", "delete")
  end

  def default_dashboard_for_user(user_id) do
    from(d in CustomDashboard, where: d.user_id == ^user_id and d.is_default == true, limit: 1)
    |> Repo.one()
  end

  def shared_dashboards do
    from(d in CustomDashboard, where: d.is_shared == true, order_by: [desc: d.updated_at])
    |> Repo.all()
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

  # ── BI Connectors ──────────────────────────────────────

  def list_bi_connectors, do: Repo.all(from(c in BiConnector, order_by: [desc: c.inserted_at], preload: [:export_logs]))
  def get_bi_connector!(id), do: Repo.get!(BiConnector, id) |> Repo.preload(:export_logs)

  def create_bi_connector(attrs) do
    %BiConnector{}
    |> BiConnector.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bi_connectors", "create")
  end

  def update_bi_connector(%BiConnector{} = connector, attrs) do
    connector
    |> BiConnector.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("bi_connectors", "update")
  end

  def delete_bi_connector(%BiConnector{} = connector) do
    Repo.delete(connector)
    |> audit_and_broadcast("bi_connectors", "delete")
  end

  def active_connectors do
    from(c in BiConnector, where: c.is_active == true, order_by: [desc: c.inserted_at])
    |> Repo.all()
  end

  def list_bi_export_logs(connector_id) do
    from(l in BiExportLog,
      where: l.connector_id == ^connector_id,
      order_by: [desc: l.inserted_at]
    )
    |> Repo.all()
  end

  def create_bi_export_log(attrs) do
    %BiExportLog{}
    |> BiExportLog.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("bi_export_logs", "create")
  end

  def latest_export_for_connector(connector_id) do
    from(l in BiExportLog,
      where: l.connector_id == ^connector_id,
      order_by: [desc: l.inserted_at, desc: l.id],
      limit: 1
    )
    |> Repo.one()
  end

  # ── Health Scores ──────────────────────────────────────

  def list_health_scores(company_id \\ nil) do
    query = from(hs in HealthScore, order_by: [desc: hs.score_date], preload: [:company])
    query = if company_id, do: where(query, [hs], hs.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_health_score!(id), do: Repo.get!(HealthScore, id) |> Repo.preload(:company)

  def create_health_score(attrs) do
    %HealthScore{}
    |> HealthScore.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("health_scores", "create")
  end

  def update_health_score(%HealthScore{} = hs, attrs) do
    hs
    |> HealthScore.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("health_scores", "update")
  end

  def delete_health_score(%HealthScore{} = hs) do
    Repo.delete(hs)
    |> audit_and_broadcast("health_scores", "delete")
  end

  def latest_health_score(company_id) do
    from(hs in HealthScore,
      where: hs.company_id == ^company_id,
      order_by: [desc: hs.score_date, desc: hs.id],
      limit: 1,
      preload: [:company]
    )
    |> Repo.one()
  end

  def health_score_trend(company_id) do
    from(hs in HealthScore,
      where: hs.company_id == ^company_id,
      order_by: [desc: hs.score_date],
      limit: 12,
      preload: [:company]
    )
    |> Repo.all()
    |> Enum.reverse()
  end

  def calculate_health_score(company_id) do
    liquidity = Decimal.new("75.0")
    profitability = Decimal.new("70.0")
    compliance = Decimal.new("85.0")
    governance = Decimal.new("80.0")
    risk = Decimal.new("72.0")
    operational = Decimal.new("78.0")

    overall =
      [liquidity, profitability, compliance, governance, risk, operational]
      |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
      |> Decimal.div(6)
      |> Decimal.round(1)

    create_health_score(%{
      company_id: company_id,
      score_date: Date.utc_today(),
      overall_score: overall,
      liquidity_score: liquidity,
      profitability_score: profitability,
      compliance_score: compliance,
      governance_score: governance,
      risk_score: risk,
      operational_score: operational,
      trend: "stable",
      components: %{
        liquidity: Decimal.to_string(liquidity),
        profitability: Decimal.to_string(profitability),
        compliance: Decimal.to_string(compliance),
        governance: Decimal.to_string(governance),
        risk: Decimal.to_string(risk),
        operational: Decimal.to_string(operational)
      }
    })
  end
end
