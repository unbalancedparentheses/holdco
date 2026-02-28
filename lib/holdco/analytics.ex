defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{Kpi, KpiSnapshot, ReportTemplate, CounterpartyExposure, LoanCovenant}

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
