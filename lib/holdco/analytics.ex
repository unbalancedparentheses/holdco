defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{Kpi, KpiSnapshot, ReportTemplate, ScheduledReport}

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
