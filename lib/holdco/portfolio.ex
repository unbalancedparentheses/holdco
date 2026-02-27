defmodule Holdco.Portfolio do
  alias Holdco.{Assets, Banking, Finance, Money, Pricing}

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
