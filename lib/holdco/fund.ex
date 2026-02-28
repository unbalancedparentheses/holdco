defmodule Holdco.Fund do
  @moduledoc """
  Context for fund management: capital calls, distributions, waterfall tiers, and K-1 reports.
  """

  import Ecto.Query
  alias Holdco.Repo
  alias Holdco.Money

  alias Holdco.Fund.{CapitalCall, CapitalCallLine, Distribution, DistributionLine, WaterfallTier, K1Report}

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
