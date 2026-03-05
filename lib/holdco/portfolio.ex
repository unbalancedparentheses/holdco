defmodule Holdco.Portfolio do
  alias Holdco.{Assets, Banking, Corporate, Finance, Money, Pricing}

  @fallback_fx_rates %{
    "USD" => Decimal.new(1),
    "EUR" => Decimal.from_float(1.08),
    "GBP" => Decimal.from_float(1.27),
    "ARS" => Decimal.from_float(0.001),
    "BRL" => Decimal.from_float(0.19)
  }

  def calculate_nav do
    holdings = Assets.list_holdings()
    bank_accounts = Banking.list_bank_accounts()
    liabilities = Finance.list_liabilities()

    liquid =
      Enum.reduce(bank_accounts, Decimal.new(0), fn ba, acc ->
        Money.add(acc, to_usd(ba.balance, ba.currency))
      end)

    {marketable, illiquid} =
      Enum.reduce(holdings, {Decimal.new(0), Decimal.new(0)}, fn h, {mkt, ill} ->
        value = holding_value(h)

        if h.asset_type in ~w(equity crypto commodity) do
          {Money.add(mkt, value), ill}
        else
          {mkt, Money.add(ill, value)}
        end
      end)

    # Add real estate and fund investments to illiquid
    real_estate = Assets.list_real_estate_properties()

    re_value =
      Enum.reduce(real_estate, Decimal.new(0), fn re, acc ->
        Money.add(acc, to_usd(re.current_valuation || re.purchase_price, re.currency))
      end)

    funds = Assets.list_fund_investments()

    fund_value =
      Enum.reduce(funds, Decimal.new(0), fn f, acc ->
        Money.add(acc, to_usd(f.nav, f.currency))
      end)

    illiquid = Money.add(illiquid, Money.add(re_value, fund_value))

    total_liabilities =
      Enum.reduce(liabilities, Decimal.new(0), fn l, acc ->
        if l.status == "active", do: Money.add(acc, to_usd(l.principal, l.currency)), else: acc
      end)

    nav = Money.sub(Money.add(Money.add(liquid, marketable), illiquid), total_liabilities)

    %{
      liquid: liquid,
      marketable: marketable,
      illiquid: illiquid,
      liabilities: total_liabilities,
      nav: nav
    }
  end

  def holding_value(holding) do
    qty = Money.to_decimal(holding.quantity)

    case holding.ticker do
      nil ->
        Decimal.new(0)

      "" ->
        Decimal.new(0)

      ticker ->
        case Pricing.get_latest_price(ticker) do
          %{price: price} -> to_usd(Money.mult(qty, price), holding.currency)
          nil -> Decimal.new(0)
        end
    end
  end

  # Dynamic FX: try Yahoo Finance live rate, fall back to hardcoded
  def get_fx_rate("USD"), do: Decimal.new(1)

  def get_fx_rate(currency) do
    case Pricing.YahooClient.fetch_fx_rate(currency) do
      {:ok, rate} -> Money.to_decimal(rate)
      {:error, _} -> Map.get(@fallback_fx_rates, currency, Decimal.new(1))
    end
  end

  def to_usd(nil, _currency), do: Decimal.new(0)
  def to_usd(amount, "USD"), do: Money.to_decimal(amount)

  def to_usd(amount, currency) do
    rate = get_fx_rate(currency)
    Money.mult(amount, rate)
  end

  # Cost basis / gains calculations
  def calculate_gains do
    holdings = Assets.list_holdings()

    per_holding =
      holdings
      |> Enum.map(fn holding ->
        lots = holding.cost_basis_lots || []
        current_value = holding_value(holding)

        # Sum up cost basis from unsold lots (remaining quantity)
        total_cost_basis =
          lots
          |> Enum.reduce(Decimal.new(0), fn lot, acc ->
            remaining = Money.sub(Money.to_decimal(lot.quantity), Money.to_decimal(lot.sold_quantity))

            if Money.gt?(remaining, 0) do
              Money.add(acc, Money.mult(remaining, Money.to_decimal(lot.price_per_unit)))
            else
              acc
            end
          end)

        unrealized_gain = Money.sub(current_value, total_cost_basis)

        # Realized gains from sold portions
        realized_gain =
          lots
          |> Enum.filter(&Money.positive?(Money.to_decimal(&1.sold_quantity)))
          |> Enum.reduce(Decimal.new(0), fn lot, acc ->
            sold_qty = Money.to_decimal(lot.sold_quantity)
            proceeds = Money.mult(sold_qty, Money.to_decimal(lot.sold_price))
            cost = Money.mult(sold_qty, Money.to_decimal(lot.price_per_unit))
            Money.add(acc, Money.sub(proceeds, cost))
          end)

        %{
          holding_id: holding.id,
          asset: holding.asset,
          ticker: holding.ticker,
          current_value: current_value,
          cost_basis: total_cost_basis,
          unrealized_gain: unrealized_gain,
          realized_gain: realized_gain,
          total_gain: Money.add(unrealized_gain, realized_gain)
        }
      end)

    aggregate = %{
      total_unrealized: Enum.reduce(per_holding, Decimal.new(0), &Money.add(&1.unrealized_gain, &2)),
      total_realized: Enum.reduce(per_holding, Decimal.new(0), &Money.add(&1.realized_gain, &2)),
      total_gain: Enum.reduce(per_holding, Decimal.new(0), &Money.add(&1.total_gain, &2))
    }

    %{per_holding: per_holding, aggregate: aggregate}
  end

  def asset_allocation do
    holdings = Assets.list_holdings()

    holdings
    |> Enum.group_by(& &1.asset_type)
    |> Enum.map(fn {type, items} ->
      value = Enum.reduce(items, Decimal.new(0), fn h, acc -> Money.add(acc, holding_value(h)) end)
      %{type: type, value: value, count: length(items)}
    end)
    |> Enum.sort_by(& &1.value, :desc)
  end

  # --- Return metrics ---

  def return_metrics do
    gains = calculate_gains()
    nav = calculate_nav()
    total_assets = Money.add(Money.add(nav.liquid, nav.marketable), nav.illiquid)

    total_cost_basis =
      Enum.reduce(gains.per_holding, Decimal.new(0), &Money.add(&1.cost_basis, &2))

    total_current_value =
      Enum.reduce(gains.per_holding, Decimal.new(0), &Money.add(&1.current_value, &2))

    total_return_pct =
      if Money.gt?(total_cost_basis, 0),
        do: Money.to_float(Money.mult(Money.div(gains.aggregate.total_gain, total_cost_basis), 100)),
        else: 0.0

    unrealized_return_pct =
      if Money.gt?(total_cost_basis, 0),
        do: Money.to_float(Money.mult(Money.div(gains.aggregate.total_unrealized, total_cost_basis), 100)),
        else: 0.0

    %{
      total_cost_basis: total_cost_basis,
      total_current_value: total_current_value,
      unrealized_gain: gains.aggregate.total_unrealized,
      realized_gain: gains.aggregate.total_realized,
      total_gain: gains.aggregate.total_gain,
      total_return_pct: total_return_pct,
      unrealized_return_pct: unrealized_return_pct,
      total_assets: total_assets,
      nav: nav.nav
    }
  end

  # --- Period-over-period comparison ---

  def period_comparison do
    snapshots = Assets.list_portfolio_snapshots() |> Enum.sort_by(& &1.date)
    nav = calculate_nav()
    current_nav = nav.nav
    today = Date.utc_today()

    periods = [
      {"1W", Date.add(today, -7)},
      {"1M", Date.add(today, -30)},
      {"3M", Date.add(today, -90)},
      {"YTD", Date.new!(today.year, 1, 1)},
      {"1Y", Date.add(today, -365)}
    ]

    Enum.map(periods, fn {label, cutoff_date} ->
      cutoff_str = Date.to_iso8601(cutoff_date)

      prior_nav =
        snapshots
        |> Enum.filter(&(&1.date <= cutoff_str))
        |> List.last()

      case prior_nav do
        nil ->
          %{label: label, prior_nav: nil, change: nil, change_pct: nil}

        snap ->
          change = Money.sub(current_nav, snap.nav)
          change_pct =
            if Money.gt?(snap.nav, 0),
              do: Money.to_float(Money.mult(Money.div(change, snap.nav), 100)),
              else: 0.0

          %{label: label, prior_nav: snap.nav, change: change, change_pct: change_pct}
      end
    end)
  end

  # --- Cash flow forecast (next N days) ---

  def cash_flow_forecast(days \\ 90) do
    today = Date.utc_today()
    horizon = Date.add(today, days)
    horizon_str = Date.to_iso8601(horizon)
    today_str = Date.to_iso8601(today)

    # Recurring transactions that will fire in the window
    recurring = Finance.list_recurring_transactions()

    recurring_flows =
      recurring
      |> Enum.filter(&(&1.is_active && &1.next_run_date && &1.next_run_date >= today_str && &1.next_run_date <= horizon_str))
      |> Enum.flat_map(fn rt ->
        expand_recurring(rt, today, horizon)
      end)

    # Liability maturities (principal repayments due in window)
    liabilities = Finance.list_liabilities()

    maturity_flows =
      liabilities
      |> Enum.filter(fn l ->
        l.status == "active" && l.maturity_date &&
          l.maturity_date >= today_str && l.maturity_date <= horizon_str
      end)
      |> Enum.map(fn l ->
        %{
          date: l.maturity_date,
          amount: Money.negate(to_usd(l.principal, l.currency)),
          description: "Debt maturity: #{l.creditor}",
          category: "debt_repayment"
        }
      end)

    # Combine and sort
    all_flows = (recurring_flows ++ maturity_flows) |> Enum.sort_by(& &1.date)

    # Running balance projection
    starting_balance =
      Banking.list_bank_accounts()
      |> Enum.reduce(Decimal.new(0), fn ba, acc -> Money.add(acc, to_usd(ba.balance, ba.currency)) end)

    {projected_flows, _} =
      Enum.map_reduce(all_flows, starting_balance, fn flow, balance ->
        new_balance = Money.add(balance, flow.amount)
        {Map.put(flow, :running_balance, new_balance), new_balance}
      end)

    total_inflows =
      all_flows |> Enum.filter(&Money.positive?(&1.amount)) |> Enum.reduce(Decimal.new(0), &Money.add(&1.amount, &2))

    total_outflows =
      all_flows |> Enum.filter(&Money.negative?(&1.amount)) |> Enum.reduce(Decimal.new(0), &Money.add(Money.abs(&1.amount), &2))

    ending_balance = Money.sub(Money.add(starting_balance, total_inflows), total_outflows)

    %{
      starting_balance: starting_balance,
      ending_balance: ending_balance,
      total_inflows: total_inflows,
      total_outflows: total_outflows,
      net_flow: Money.sub(total_inflows, total_outflows),
      flows: projected_flows,
      days: days
    }
  end

  defp expand_recurring(rt, today, horizon) do
    amount_usd = to_usd(rt.amount, rt.currency)
    signed_amount = if rt.transaction_type in ~w(expense transfer_out), do: Money.negate(amount_usd), else: amount_usd

    case Date.from_iso8601(rt.next_run_date) do
      {:ok, start_date} ->
        Stream.iterate(start_date, &advance_date(&1, rt.frequency))
        |> Stream.take_while(fn d -> Date.compare(d, horizon) != :gt end)
        |> Stream.filter(fn d -> Date.compare(d, today) != :lt end)
        |> Enum.map(fn d ->
          %{
            date: Date.to_iso8601(d),
            amount: signed_amount,
            description: rt.description,
            category: rt.transaction_type || "recurring"
          }
        end)

      _ ->
        []
    end
  end

  defp advance_date(date, "daily"), do: Date.add(date, 1)
  defp advance_date(date, "weekly"), do: Date.add(date, 7)
  defp advance_date(date, "monthly") do
    {y, m, d} = Date.to_erl(date)
    m2 = m + 1
    {y2, m3} = if m2 > 12, do: {y + 1, m2 - 12}, else: {y, m2}
    d2 = min(d, Calendar.ISO.days_in_month(y2, m3))
    Date.new!(y2, m3, d2)
  end
  defp advance_date(date, "quarterly") do
    date |> advance_date("monthly") |> advance_date("monthly") |> advance_date("monthly")
  end
  defp advance_date(date, "yearly") do
    {y, m, d} = Date.to_erl(date)
    d2 = min(d, Calendar.ISO.days_in_month(y + 1, m))
    Date.new!(y + 1, m, d2)
  end
  defp advance_date(date, _), do: Date.add(date, 30)

  # --- Financial ratios ---

  def financial_ratios do
    nav = calculate_nav()
    total_assets = Money.add(Money.add(nav.liquid, nav.marketable), nav.illiquid)
    equity = Money.sub(total_assets, nav.liabilities)

    debt_to_equity =
      if Money.gt?(equity, 0),
        do: Money.to_float(Money.div(nav.liabilities, equity)),
        else: nil

    # Current ratio: liquid assets / short-term liabilities (maturing within 1 year)
    liabilities = Finance.list_liabilities()
    today_str = Date.to_iso8601(Date.utc_today())
    one_year = Date.to_iso8601(Date.add(Date.utc_today(), 365))

    short_term_liabilities =
      liabilities
      |> Enum.filter(fn l ->
        l.status == "active" &&
          (l.maturity_date == nil || l.maturity_date <= one_year) &&
          (l.maturity_date == nil || l.maturity_date >= today_str)
      end)
      |> Enum.reduce(Decimal.new(0), fn l, acc -> Money.add(acc, to_usd(l.principal, l.currency)) end)

    current_ratio =
      if Money.gt?(short_term_liabilities, 0),
        do: Money.to_float(Money.div(nav.liquid, short_term_liabilities)),
        else: nil

    liquid_to_total =
      if Money.gt?(total_assets, 0),
        do: Money.to_float(Money.mult(Money.div(nav.liquid, total_assets), 100)),
        else: 0.0

    # Weighted average interest rate on debt
    active_liabilities = Enum.filter(liabilities, &(&1.status == "active"))

    total_principal =
      Enum.reduce(active_liabilities, Decimal.new(0), fn l, acc ->
        Money.add(acc, to_usd(l.principal, l.currency))
      end)

    weighted_rate =
      if Money.gt?(total_principal, 0) do
        weighted_sum =
          Enum.reduce(active_liabilities, Decimal.new(0), fn l, acc ->
            rate = Money.to_decimal(l.interest_rate || 0)
            principal_usd = to_usd(l.principal, l.currency)
            Money.add(acc, Money.mult(rate, principal_usd))
          end)

        Money.to_float(Money.div(weighted_sum, total_principal))
      else
        nil
      end

    %{
      total_assets: total_assets,
      total_liabilities: nav.liabilities,
      equity: equity,
      debt_to_equity: debt_to_equity,
      current_ratio: current_ratio,
      liquid_to_total_pct: liquid_to_total,
      weighted_avg_interest_rate: weighted_rate,
      short_term_liabilities: short_term_liabilities
    }
  end

  # --- Entity-level performance ---

  def entity_performance do
    companies = Corporate.list_companies()
    holdings = Assets.list_holdings()
    bank_accounts = Banking.list_bank_accounts()
    liabilities = Finance.list_liabilities()

    holdings_by_company = Enum.group_by(holdings, & &1.company_id)
    accounts_by_company = Enum.group_by(bank_accounts, & &1.company_id)
    liabilities_by_company = Enum.group_by(liabilities, & &1.company_id)

    companies
    |> Enum.map(fn company ->
      co_holdings = Map.get(holdings_by_company, company.id, [])
      co_accounts = Map.get(accounts_by_company, company.id, [])
      co_liabilities = Map.get(liabilities_by_company, company.id, [])

      liquid =
        Enum.reduce(co_accounts, Decimal.new(0), fn ba, acc ->
          Money.add(acc, to_usd(ba.balance, ba.currency))
        end)

      holdings_value =
        Enum.reduce(co_holdings, Decimal.new(0), fn h, acc ->
          Money.add(acc, holding_value(h))
        end)

      total_liab =
        co_liabilities
        |> Enum.filter(&(&1.status == "active"))
        |> Enum.reduce(Decimal.new(0), fn l, acc -> Money.add(acc, to_usd(l.principal, l.currency)) end)

      total_assets = Money.add(liquid, holdings_value)
      entity_nav = Money.sub(total_assets, total_liab)

      # Cost basis for return calc
      cost_basis =
        Enum.reduce(co_holdings, Decimal.new(0), fn h, acc ->
          lots = h.cost_basis_lots || []
          lot_cost =
            Enum.reduce(lots, Decimal.new(0), fn lot, a ->
              remaining = Money.sub(Money.to_decimal(lot.quantity), Money.to_decimal(lot.sold_quantity))
              if Money.gt?(remaining, 0),
                do: Money.add(a, Money.mult(remaining, Money.to_decimal(lot.price_per_unit))),
                else: a
            end)
          Money.add(acc, lot_cost)
        end)

      unrealized_gain = Money.sub(holdings_value, cost_basis)

      return_pct =
        if Money.gt?(cost_basis, 0),
          do: Money.to_float(Money.mult(Money.div(unrealized_gain, cost_basis), 100)),
          else: nil

      %{
        id: company.id,
        name: company.name,
        category: company.category,
        liquid: liquid,
        holdings_value: holdings_value,
        total_assets: total_assets,
        liabilities: total_liab,
        nav: entity_nav,
        unrealized_gain: unrealized_gain,
        return_pct: return_pct
      }
    end)
    |> Enum.sort_by(& &1.nav, {:desc, Decimal})
  end

  def fx_exposure do
    bank_accounts = Banking.list_bank_accounts()
    holdings = Assets.list_holdings()

    balances_by_ccy =
      Enum.group_by(bank_accounts, & &1.currency)
      |> Enum.map(fn {ccy, accs} ->
        total = Enum.reduce(accs, Decimal.new(0), fn a, sum -> Money.add(Money.to_decimal(a.balance), sum) end)
        %{currency: ccy, amount: total, usd_value: to_usd(total, ccy)}
      end)

    holdings_by_ccy =
      Enum.group_by(holdings, & &1.currency)
      |> Enum.map(fn {ccy, hs} ->
        total = Enum.reduce(hs, Decimal.new(0), fn h, acc -> Money.add(acc, holding_value(h)) end)
        %{currency: ccy, amount: total, usd_value: total}
      end)

    (balances_by_ccy ++ holdings_by_ccy)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {ccy, items} ->
      %{
        currency: ccy,
        usd_value: Enum.reduce(items, Decimal.new(0), fn item, sum -> Money.add(item.usd_value, sum) end)
      }
    end)
    |> Enum.sort_by(& &1.usd_value, :desc)
  end
end
