defmodule Holdco.Fund do
  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Fund.{FundNav, InvestorStatement, FundFee}

  # ── Fund NAV CRUD ─────────────────────────────────────

  def list_fund_navs(company_id \\ nil) do
    query = from(n in FundNav, order_by: [desc: n.nav_date], preload: [:company])
    query = if company_id, do: where(query, [n], n.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_fund_nav!(id), do: Repo.get!(FundNav, id) |> Repo.preload(:company)

  def create_fund_nav(attrs) do
    %FundNav{}
    |> FundNav.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("fund_navs", "create")
  end

  def update_fund_nav(%FundNav{} = nav, attrs) do
    nav
    |> FundNav.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("fund_navs", "update")
  end

  def delete_fund_nav(%FundNav{} = nav) do
    Repo.delete(nav)
    |> audit_and_broadcast("fund_navs", "delete")
  end

  @doc """
  Calculate NAV for a company by summing holdings values + bank balances - liabilities.
  Returns a map with :total_assets, :total_liabilities, :net_asset_value, :nav_per_unit.
  """
  def calculate_fund_nav(company_id) do
    # Get holdings value from cost basis lots (quantity * price_per_unit)
    holdings_value =
      from(cbl in Holdco.Assets.CostBasisLot,
        join: h in Holdco.Assets.AssetHolding,
        on: cbl.holding_id == h.id,
        where: h.company_id == ^company_id,
        select: coalesce(sum(cbl.quantity * cbl.price_per_unit), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Get bank balances
    bank_balances =
      from(ba in Holdco.Banking.BankAccount,
        where: ba.company_id == ^company_id,
        select: coalesce(sum(ba.balance), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Get fund investment NAVs
    fund_nav_value =
      from(fi in Holdco.Assets.FundInvestment,
        where: fi.company_id == ^company_id,
        select: coalesce(sum(fi.nav), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    total_assets = holdings_value |> Money.add(bank_balances) |> Money.add(fund_nav_value)

    # Get liabilities
    total_liabilities =
      from(l in Holdco.Finance.Liability,
        where: l.company_id == ^company_id and l.status == "active",
        select: coalesce(sum(l.principal), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    net_asset_value = Money.sub(total_assets, total_liabilities)

    # Get units outstanding from the latest NAV record
    latest_nav =
      from(n in FundNav,
        where: n.company_id == ^company_id,
        order_by: [desc: n.nav_date],
        limit: 1
      )
      |> Repo.one()

    units_outstanding =
      if latest_nav && latest_nav.units_outstanding,
        do: Money.to_decimal(latest_nav.units_outstanding),
        else: Decimal.new(1)

    nav_per_unit = Money.div(net_asset_value, units_outstanding)

    %{
      total_assets: total_assets,
      total_liabilities: total_liabilities,
      net_asset_value: net_asset_value,
      nav_per_unit: nav_per_unit,
      units_outstanding: units_outstanding
    }
  end

  # ── Investor Statements CRUD ──────────────────────────

  def list_investor_statements(opts \\ []) do
    query = from(s in InvestorStatement, order_by: [desc: s.period_end], preload: [:company])

    query =
      Enum.reduce(opts, query, fn
        {:company_id, id}, q when not is_nil(id) -> where(q, [s], s.company_id == ^id)
        {:investor_name, name}, q when not is_nil(name) -> where(q, [s], s.investor_name == ^name)
        {:status, status}, q when not is_nil(status) -> where(q, [s], s.status == ^status)
        _, q -> q
      end)

    Repo.all(query)
  end

  def get_investor_statement!(id), do: Repo.get!(InvestorStatement, id) |> Repo.preload(:company)

  def create_investor_statement(attrs) do
    %InvestorStatement{}
    |> InvestorStatement.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("investor_statements", "create")
  end

  def update_investor_statement(%InvestorStatement{} = stmt, attrs) do
    stmt
    |> InvestorStatement.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("investor_statements", "update")
  end

  def delete_investor_statement(%InvestorStatement{} = stmt) do
    Repo.delete(stmt)
    |> audit_and_broadcast("investor_statements", "delete")
  end

  @doc """
  Generate an investor statement for a given company, investor, and period.
  Pulls from capital contributions (as contributions) and dividends (as distributions),
  then calculates balances, MOIC, and a simplified IRR estimate.
  """
  def generate_investor_statement(company_id, investor_name, period_start, period_end) do
    # CapitalContribution.date and Dividend.date are :string fields (ISO 8601),
    # so we must compare with string representations.
    ps = Date.to_iso8601(period_start)
    pe = Date.to_iso8601(period_end)

    # Get contributions (capital contributions) for the period
    contributions =
      from(cc in Holdco.Finance.CapitalContribution,
        where:
          cc.company_id == ^company_id and
            cc.contributor == ^investor_name and
            cc.date >= ^ps and
            cc.date <= ^pe,
        select: coalesce(sum(cc.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Get total contributions for MOIC (all time up to period_end)
    total_contributions =
      from(cc in Holdco.Finance.CapitalContribution,
        where:
          cc.company_id == ^company_id and
            cc.contributor == ^investor_name and
            cc.date <= ^pe,
        select: coalesce(sum(cc.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Get distributions (dividends) for the period
    distributions =
      from(d in Holdco.Finance.Dividend,
        where:
          d.company_id == ^company_id and
            d.date >= ^ps and
            d.date <= ^pe,
        select: coalesce(sum(d.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Get total distributions for MOIC (all time up to period_end)
    total_distributions =
      from(d in Holdco.Finance.Dividend,
        where:
          d.company_id == ^company_id and
            d.date <= ^pe,
        select: coalesce(sum(d.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    # Beginning balance: total contributions before period - total distributions before period
    contributions_before =
      from(cc in Holdco.Finance.CapitalContribution,
        where:
          cc.company_id == ^company_id and
            cc.contributor == ^investor_name and
            cc.date < ^ps,
        select: coalesce(sum(cc.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    distributions_before =
      from(d in Holdco.Finance.Dividend,
        where:
          d.company_id == ^company_id and
            d.date < ^ps,
        select: coalesce(sum(d.amount), 0)
      )
      |> Repo.one()
      |> Money.to_decimal()

    beginning_balance = Money.sub(contributions_before, distributions_before)
    ending_balance =
      beginning_balance
      |> Money.add(contributions)
      |> Money.sub(distributions)

    # MOIC = total value / total invested
    # total value = ending_balance + total_distributions
    total_value = Money.add(ending_balance, total_distributions)
    moic = Money.div(total_value, total_contributions)

    # Simple annualized return as a proxy for IRR
    # IRR approximation: (MOIC ^ (1/years)) - 1
    period_days = Date.diff(period_end, period_start)
    years = if period_days > 0, do: period_days / 365.25, else: 1.0

    irr =
      if Money.positive?(total_contributions) and Money.positive?(total_value) do
        moic_float = Money.to_float(moic)
        irr_value = :math.pow(moic_float, 1.0 / years) - 1.0
        Decimal.from_float(irr_value * 100.0) |> Decimal.round(2)
      else
        Decimal.new(0)
      end

    %{
      company_id: company_id,
      investor_name: investor_name,
      period_start: period_start,
      period_end: period_end,
      beginning_balance: beginning_balance,
      contributions: contributions,
      distributions: distributions,
      ending_balance: ending_balance,
      moic: moic |> Decimal.round(4),
      irr: irr,
      status: "draft"
    }
  end

  # ── Fund Fees CRUD ────────────────────────────────────

  def list_fund_fees(company_id \\ nil) do
    query = from(f in FundFee, order_by: [desc: f.inserted_at], preload: [:company])
    query = if company_id, do: where(query, [f], f.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_fund_fee!(id), do: Repo.get!(FundFee, id) |> Repo.preload(:company)

  def create_fund_fee(attrs) do
    %FundFee{}
    |> FundFee.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("fund_fees", "create")
  end

  def update_fund_fee(%FundFee{} = fee, attrs) do
    fee
    |> FundFee.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("fund_fees", "update")
  end

  def delete_fund_fee(%FundFee{} = fee) do
    Repo.delete(fee)
    |> audit_and_broadcast("fund_fees", "delete")
  end

  @doc """
  Calculate a management fee based on a rate, basis type, and period.
  Returns a map with the fee details ready to be inserted.
  """
  def calculate_management_fee(company_id, rate_pct, basis, period_start, period_end) do
    basis_amount = get_basis_amount(company_id, basis)

    # Prorate for the period (days in period / 365)
    period_days = Date.diff(period_end, period_start)
    proration = Decimal.from_float(period_days / 365.0)

    rate_decimal = Money.div(Money.to_decimal(rate_pct), Decimal.new(100))
    amount = basis_amount |> Money.mult(rate_decimal) |> Money.mult(proration) |> Money.round(2)

    %{
      company_id: company_id,
      fee_type: "management",
      description: "Management fee (#{rate_pct}% on #{basis})",
      amount: amount,
      period_start: period_start,
      period_end: period_end,
      basis: basis,
      rate_pct: Money.to_decimal(rate_pct),
      calculation_basis_amount: basis_amount,
      status: "accrued"
    }
  end

  defp get_basis_amount(company_id, "nav") do
    nav_data = calculate_fund_nav(company_id)
    nav_data.net_asset_value
  end

  defp get_basis_amount(company_id, "committed_capital") do
    from(fi in Holdco.Assets.FundInvestment,
      where: fi.company_id == ^company_id,
      select: coalesce(sum(fi.commitment), 0)
    )
    |> Repo.one()
    |> Money.to_decimal()
  end

  defp get_basis_amount(company_id, "invested_capital") do
    from(fi in Holdco.Assets.FundInvestment,
      where: fi.company_id == ^company_id,
      select: coalesce(sum(fi.called), 0)
    )
    |> Repo.one()
    |> Money.to_decimal()
  end

  defp get_basis_amount(_company_id, _basis), do: Decimal.new(0)

  @doc """
  Fee summary for a company: totals by type, paid vs accrued, and grand total.
  """
  def fee_summary(company_id) do
    fees = list_fund_fees(company_id)

    by_type =
      fees
      |> Enum.group_by(& &1.fee_type)
      |> Enum.map(fn {type, type_fees} ->
        {type, Money.sum(Enum.map(type_fees, & &1.amount))}
      end)
      |> Enum.into(%{})

    by_status =
      fees
      |> Enum.group_by(& &1.status)
      |> Enum.map(fn {status, status_fees} ->
        {status, Money.sum(Enum.map(status_fees, & &1.amount))}
      end)
      |> Enum.into(%{})

    total = Money.sum(Enum.map(fees, & &1.amount))

    %{
      by_type: by_type,
      by_status: by_status,
      total: total,
      count: length(fees)
    }
  end

  # ── PubSub ────────────────────────────────────────────

  def subscribe, do: Phoenix.PubSub.subscribe(Holdco.PubSub, "fund")
  defp broadcast(message), do: Phoenix.PubSub.broadcast(Holdco.PubSub, "fund", message)

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
