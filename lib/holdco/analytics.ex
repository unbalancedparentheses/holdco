defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{Kpi, KpiSnapshot, ReportTemplate, ScheduledReport, StressTest, LiquidityCoverage}

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
