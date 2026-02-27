defmodule Holdco.Analytics do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Analytics.{Kpi, KpiSnapshot, ReportTemplate}

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
