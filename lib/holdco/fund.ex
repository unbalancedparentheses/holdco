defmodule Holdco.Fund do
  @moduledoc """
  Context for fund management: capital calls, distributions, waterfall tiers, K-1 reports,
  fund NAV, investor statements, and fund fees.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Fund.{CapitalCall, CapitalCallLine, Distribution, DistributionLine, WaterfallTier, K1Report, FundNav, InvestorStatement, FundFee}

  # ── Capital Calls ──────────────────────────────────────

  def list_capital_calls(company_id \\ nil) do
    query = from(cc in CapitalCall, order_by: [desc: cc.call_date], preload: [:company, :lines])
    query = if company_id, do: where(query, [cc], cc.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_capital_call!(id), do: Repo.get!(CapitalCall, id) |> Repo.preload([:company, :lines])

  def create_capital_call(attrs) do
    %CapitalCall{}
    |> CapitalCall.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("capital_calls", "create")
  end

  def update_capital_call(%CapitalCall{} = cc, attrs) do
    cc
    |> CapitalCall.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("capital_calls", "update")
  end

  def delete_capital_call(%CapitalCall{} = cc) do
    Repo.delete(cc)
    |> audit_and_broadcast("capital_calls", "delete")
  end

  # ── Capital Call Lines ─────────────────────────────────

  def list_capital_call_lines(capital_call_id) do
    from(l in CapitalCallLine, where: l.capital_call_id == ^capital_call_id, order_by: l.investor_name)
    |> Repo.all()
  end

  def get_capital_call_line!(id), do: Repo.get!(CapitalCallLine, id)

  def create_capital_call_line(attrs) do
    %CapitalCallLine{}
    |> CapitalCallLine.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("capital_call_lines", "create")
  end

  def update_capital_call_line(%CapitalCallLine{} = line, attrs) do
    line
    |> CapitalCallLine.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("capital_call_lines", "update")
  end

  def delete_capital_call_line(%CapitalCallLine{} = line) do
    Repo.delete(line)
    |> audit_and_broadcast("capital_call_lines", "delete")
  end

  @doc """
  Mark a capital call line as paid, updating the paid_amount and status.
  Also updates the parent capital call status if all lines are paid.
  """
  def mark_line_paid(%CapitalCallLine{} = line, paid_amount, paid_date \\ Date.utc_today()) do
    result =
      line
      |> CapitalCallLine.changeset(%{
        paid_amount: paid_amount,
        paid_date: paid_date,
        status: "paid"
      })
      |> Repo.update()

    case result do
      {:ok, updated_line} ->
        maybe_update_call_status(updated_line.capital_call_id)
        audit_and_broadcast({:ok, updated_line}, "capital_call_lines", "update")

      error ->
        error
    end
  end

  defp maybe_update_call_status(capital_call_id) do
    lines = list_capital_call_lines(capital_call_id)
    call = Repo.get!(CapitalCall, capital_call_id)

    new_status =
      cond do
        Enum.all?(lines, &(&1.status == "paid")) -> "funded"
        Enum.any?(lines, &(&1.status == "paid")) -> "partially_funded"
        true -> "pending"
      end

    if call.status != new_status do
      call
      |> CapitalCall.changeset(%{status: new_status})
      |> Repo.update()
    end
  end

  # ── Distributions ──────────────────────────────────────

  def list_distributions(company_id \\ nil) do
    query = from(d in Distribution, order_by: [desc: d.distribution_date], preload: [:company, :lines])
    query = if company_id, do: where(query, [d], d.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_distribution!(id), do: Repo.get!(Distribution, id) |> Repo.preload([:company, :lines])

  def create_distribution(attrs) do
    %Distribution{}
    |> Distribution.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("distributions", "create")
  end

  def update_distribution(%Distribution{} = dist, attrs) do
    dist
    |> Distribution.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("distributions", "update")
  end

  def delete_distribution(%Distribution{} = dist) do
    Repo.delete(dist)
    |> audit_and_broadcast("distributions", "delete")
  end

  # ── Distribution Lines ─────────────────────────────────

  def list_distribution_lines(distribution_id) do
    from(l in DistributionLine, where: l.distribution_id == ^distribution_id, order_by: l.investor_name)
    |> Repo.all()
  end

  def get_distribution_line!(id), do: Repo.get!(DistributionLine, id)

  def create_distribution_line(attrs) do
    %DistributionLine{}
    |> DistributionLine.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("distribution_lines", "create")
  end

  def update_distribution_line(%DistributionLine{} = line, attrs) do
    line
    |> DistributionLine.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("distribution_lines", "update")
  end

  def delete_distribution_line(%DistributionLine{} = line) do
    Repo.delete(line)
    |> audit_and_broadcast("distribution_lines", "delete")
  end

  @doc """
  Auto-calculate distribution lines for investors based on ownership percentages.
  Takes a distribution_id and a list of investors with ownership_pct.
  Each investor map: %{investor_name: "...", ownership_pct: Decimal, withholding_tax_rate: Decimal (optional)}
  """
  def calculate_distribution_lines(distribution_id, investors) do
    distribution = get_distribution!(distribution_id)
    total = Money.to_decimal(distribution.total_amount)

    Enum.map(investors, fn inv ->
      pct = Money.to_decimal(inv[:ownership_pct] || inv["ownership_pct"] || 0)
      wh_rate = Money.to_decimal(inv[:withholding_tax_rate] || inv["withholding_tax_rate"] || 0)
      gross = Money.mult(total, Money.div(pct, 100))
      withholding = Money.mult(gross, wh_rate)
      net = Money.sub(gross, withholding)

      create_distribution_line(%{
        distribution_id: distribution_id,
        investor_name: inv[:investor_name] || inv["investor_name"],
        ownership_pct: pct,
        gross_amount: gross,
        withholding_tax: withholding,
        net_amount: net
      })
    end)
  end

  # ── Waterfall Tiers ────────────────────────────────────

  def list_waterfall_tiers(company_id) do
    from(t in WaterfallTier, where: t.company_id == ^company_id, order_by: t.tier_order, preload: [:company])
    |> Repo.all()
  end

  def get_waterfall_tier!(id), do: Repo.get!(WaterfallTier, id) |> Repo.preload([:company])

  def create_waterfall_tier(attrs) do
    %WaterfallTier{}
    |> WaterfallTier.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("waterfall_tiers", "create")
  end

  def update_waterfall_tier(%WaterfallTier{} = tier, attrs) do
    tier
    |> WaterfallTier.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("waterfall_tiers", "update")
  end

  def delete_waterfall_tier(%WaterfallTier{} = tier) do
    Repo.delete(tier)
    |> audit_and_broadcast("waterfall_tiers", "delete")
  end

  @doc """
  Calculate distribution waterfall given a total distributable amount, contributed capital,
  and ordered tiers.

  Returns a list of maps: %{tier_name, tier_type, lp_amount, gp_amount, total_allocated}

  Waterfall logic:
  1. return_of_capital: LP gets back contributed capital (up to remaining)
  2. preferred_return: LP gets preferred return on unreturned capital (hurdle_rate as multiplier of capital)
  3. catch_up: GP catches up to equalize (GP gets 100% until GP share equals carried interest of total profit)
  4. carried_interest/residual: remaining split per split_lp_pct/split_gp_pct
  """
  def calculate_waterfall(distributable_amount, contributed_capital, tiers) do
    distributable = Money.to_decimal(distributable_amount)
    capital = Money.to_decimal(contributed_capital)
    zero = Decimal.new(0)

    # State: {allocations, remaining, unreturned_capital, original_capital}
    {allocations, _remaining, _unreturned, _original} =
      Enum.reduce(tiers, {[], distributable, capital, capital}, fn tier, {allocs, remaining, unreturned, original} ->
        if lte_zero?(remaining) do
          alloc = %{
            tier_name: tier.name,
            tier_type: tier.tier_type,
            lp_amount: zero,
            gp_amount: zero,
            total_allocated: zero
          }
          {allocs ++ [alloc], remaining, unreturned, original}
        else
          {lp, gp, new_remaining, new_unreturned} =
            calculate_tier(tier, remaining, unreturned, original)

          alloc = %{
            tier_name: tier.name,
            tier_type: tier.tier_type,
            lp_amount: Money.round(lp),
            gp_amount: Money.round(gp),
            total_allocated: Money.round(Money.add(lp, gp))
          }

          {allocs ++ [alloc], new_remaining, new_unreturned, original}
        end
      end)

    allocations
  end

  defp calculate_tier(tier, remaining, unreturned, original_capital) do
    zero = Decimal.new(0)

    case tier.tier_type do
      "return_of_capital" ->
        # LP gets back contributed capital
        lp_amount = Money.min(remaining, unreturned)
        new_unreturned = Money.sub(unreturned, lp_amount)
        new_remaining = Money.sub(remaining, lp_amount)
        {lp_amount, zero, new_remaining, new_unreturned}

      "preferred_return" ->
        # LP gets preferred return on original contributed capital
        hurdle = Money.to_decimal(tier.hurdle_rate || 0)
        preferred = Money.mult(original_capital, hurdle)
        lp_amount = Money.min(remaining, preferred)
        new_remaining = Money.sub(remaining, lp_amount)
        {lp_amount, zero, new_remaining, unreturned}

      "catch_up" ->
        # GP gets 100% until caught up
        gp_pct = Money.to_decimal(tier.split_gp_pct || 100)
        lp_pct = Money.to_decimal(tier.split_lp_pct || 0)
        total_pct = Money.add(gp_pct, lp_pct)

        if Money.zero?(total_pct) do
          {zero, zero, remaining, unreturned}
        else
          gp_share = Money.div(gp_pct, total_pct)
          lp_share = Money.div(lp_pct, total_pct)
          gp_amount = Money.mult(remaining, gp_share)
          lp_amount = Money.mult(remaining, lp_share)
          used = Money.add(gp_amount, lp_amount)
          new_remaining = Money.sub(remaining, used)
          {Money.min(lp_amount, remaining), Money.min(gp_amount, remaining), new_remaining, unreturned}
        end

      _carried_or_residual ->
        # Split remaining per LP/GP percentages
        lp_pct = Money.to_decimal(tier.split_lp_pct || 80)
        gp_pct = Money.to_decimal(tier.split_gp_pct || 20)
        total_pct = Money.add(lp_pct, gp_pct)

        if Money.zero?(total_pct) do
          {zero, zero, remaining, unreturned}
        else
          lp_share = Money.div(lp_pct, total_pct)
          gp_share = Money.div(gp_pct, total_pct)
          lp_amount = Money.mult(remaining, lp_share)
          gp_amount = Money.mult(remaining, gp_share)
          new_remaining = Decimal.new(0)
          {lp_amount, gp_amount, new_remaining, unreturned}
        end
    end
  end

  # ── K-1 Reports ────────────────────────────────────────

  def list_k1_reports(company_id \\ nil) do
    query = from(k in K1Report, order_by: [desc: k.tax_year, asc: k.investor_name], preload: [:company])
    query = if company_id, do: where(query, [k], k.company_id == ^company_id), else: query
    Repo.all(query)
  end

  def get_k1_report!(id), do: Repo.get!(K1Report, id) |> Repo.preload([:company])

  def create_k1_report(attrs) do
    %K1Report{}
    |> K1Report.changeset(attrs)
    |> Repo.insert()
    |> audit_and_broadcast("k1_reports", "create")
  end

  def update_k1_report(%K1Report{} = k1, attrs) do
    k1
    |> K1Report.changeset(attrs)
    |> Repo.update()
    |> audit_and_broadcast("k1_reports", "update")
  end

  def delete_k1_report(%K1Report{} = k1) do
    Repo.delete(k1)
    |> audit_and_broadcast("k1_reports", "delete")
  end

  @doc """
  Generate a K-1 report for a given company, tax year, and investor.
  Pulls distribution data from the distributions table for that year.
  """
  def generate_k1(company_id, tax_year, investor_name) do
    year_start = Date.new!(tax_year, 1, 1)
    year_end = Date.new!(tax_year, 12, 31)

    # Find all distribution lines for this investor in this company for the tax year
    distribution_lines =
      from(dl in DistributionLine,
        join: d in Distribution,
        on: dl.distribution_id == d.id,
        where: d.company_id == ^company_id,
        where: d.distribution_date >= ^year_start,
        where: d.distribution_date <= ^year_end,
        where: dl.investor_name == ^investor_name,
        preload: [distribution: d]
      )
      |> Repo.all()

    total_distributions =
      distribution_lines
      |> Enum.reduce(Decimal.new(0), fn dl, acc ->
        Money.add(acc, Money.to_decimal(dl.net_amount || dl.gross_amount))
      end)

    # Categorize by distribution type
    {ordinary, st_gains, lt_gains, roc} =
      Enum.reduce(distribution_lines, {Decimal.new(0), Decimal.new(0), Decimal.new(0), Decimal.new(0)},
        fn dl, {ord, st, lt, rc} ->
          amount = Money.to_decimal(dl.net_amount || dl.gross_amount)
          dist = dl.distribution

          case dist.distribution_type do
            "dividend" -> {Money.add(ord, amount), st, lt, rc}
            "profit" -> {ord, st, Money.add(lt, amount), rc}
            "return_of_capital" -> {ord, st, lt, Money.add(rc, amount)}
            _ -> {Money.add(ord, amount), st, lt, rc}
          end
        end)

    create_k1_report(%{
      company_id: company_id,
      tax_year: tax_year,
      investor_name: investor_name,
      ordinary_income: ordinary,
      short_term_capital_gains: st_gains,
      long_term_capital_gains: lt_gains,
      total_distributions: total_distributions,
      beginning_capital: roc,
      status: "draft"
    })
  end

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

  # ── PubSub ─────────────────────────────────────────────

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

  # Helper for waterfall: check if remaining <= 0
  defp lte_zero?(decimal) do
    Decimal.compare(decimal, Decimal.new(0)) in [:lt, :eq]
  end
end
