defmodule Holdco.Portfolio do
  alias Holdco.{Assets, Banking, Finance, Pricing}

  @fallback_fx_rates %{"USD" => 1.0, "EUR" => 1.08, "GBP" => 1.27, "ARS" => 0.001, "BRL" => 0.19}

  def calculate_nav do
    holdings = Assets.list_holdings()
    bank_accounts = Banking.list_bank_accounts()
    liabilities = Finance.list_liabilities()

    liquid =
      Enum.reduce(bank_accounts, 0.0, fn ba, acc ->
        acc + to_usd(ba.balance, ba.currency)
      end)

    {marketable, illiquid} =
      Enum.reduce(holdings, {0.0, 0.0}, fn h, {mkt, ill} ->
        value = holding_value(h)

        if h.asset_type in ~w(equity crypto commodity) do
          {mkt + value, ill}
        else
          {mkt, ill + value}
        end
      end)

    # Add real estate and fund investments to illiquid
    real_estate = Assets.list_real_estate_properties()

    re_value =
      Enum.reduce(real_estate, 0.0, fn re, acc ->
        acc + to_usd(re.current_valuation || re.purchase_price || 0.0, re.currency)
      end)

    funds = Assets.list_fund_investments()

    fund_value =
      Enum.reduce(funds, 0.0, fn f, acc ->
        acc + to_usd(f.nav, f.currency)
      end)

    illiquid = illiquid + re_value + fund_value

    total_liabilities =
      Enum.reduce(liabilities, 0.0, fn l, acc ->
        if l.status == "active", do: acc + to_usd(l.principal, l.currency), else: acc
      end)

    nav = liquid + marketable + illiquid - total_liabilities

    %{
      liquid: liquid,
      marketable: marketable,
      illiquid: illiquid,
      liabilities: total_liabilities,
      nav: nav
    }
  end

  def holding_value(holding) do
    qty = holding.quantity || 0.0

    case holding.ticker do
      nil ->
        0.0

      "" ->
        0.0

      ticker ->
        case Pricing.get_latest_price(ticker) do
          %{price: price} -> to_usd(qty * price, holding.currency)
          nil -> 0.0
        end
    end
  end

  # Dynamic FX: try Yahoo Finance live rate, fall back to hardcoded
  def get_fx_rate("USD"), do: 1.0

  def get_fx_rate(currency) do
    case Pricing.YahooClient.fetch_fx_rate(currency) do
      {:ok, rate} -> rate
      {:error, _} -> Map.get(@fallback_fx_rates, currency, 1.0)
    end
  end

  def to_usd(nil, _currency), do: 0.0
  def to_usd(amount, "USD"), do: amount

  def to_usd(amount, currency) do
    rate = get_fx_rate(currency)
    amount * rate
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
          |> Enum.reduce(0.0, fn lot, acc ->
            remaining = (lot.quantity || 0.0) - (lot.sold_quantity || 0.0)

            if remaining > 0 do
              acc + remaining * (lot.price_per_unit || 0.0)
            else
              acc
            end
          end)

        unrealized_gain = current_value - total_cost_basis

        # Realized gains from sold portions
        realized_gain =
          lots
          |> Enum.filter(&((&1.sold_quantity || 0.0) > 0))
          |> Enum.reduce(0.0, fn lot, acc ->
            proceeds = (lot.sold_quantity || 0.0) * (lot.sold_price || 0.0)
            cost = (lot.sold_quantity || 0.0) * (lot.price_per_unit || 0.0)
            acc + (proceeds - cost)
          end)

        %{
          holding_id: holding.id,
          asset: holding.asset,
          ticker: holding.ticker,
          current_value: current_value,
          cost_basis: total_cost_basis,
          unrealized_gain: unrealized_gain,
          realized_gain: realized_gain,
          total_gain: unrealized_gain + realized_gain
        }
      end)

    aggregate = %{
      total_unrealized: Enum.reduce(per_holding, 0.0, &(&1.unrealized_gain + &2)),
      total_realized: Enum.reduce(per_holding, 0.0, &(&1.realized_gain + &2)),
      total_gain: Enum.reduce(per_holding, 0.0, &(&1.total_gain + &2))
    }

    %{per_holding: per_holding, aggregate: aggregate}
  end

  def asset_allocation do
    holdings = Assets.list_holdings()

    holdings
    |> Enum.group_by(& &1.asset_type)
    |> Enum.map(fn {type, items} ->
      value = Enum.reduce(items, 0.0, fn h, acc -> acc + holding_value(h) end)
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
        total = Enum.reduce(accs, 0.0, fn acc, sum -> acc.balance + sum end)
        %{currency: ccy, amount: total, usd_value: to_usd(total, ccy)}
      end)

    holdings_by_ccy =
      Enum.group_by(holdings, & &1.currency)
      |> Enum.map(fn {ccy, hs} ->
        total = Enum.reduce(hs, 0.0, fn h, acc -> acc + holding_value(h) end)
        %{currency: ccy, amount: total, usd_value: total}
      end)

    (balances_by_ccy ++ holdings_by_ccy)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {ccy, items} ->
      %{
        currency: ccy,
        usd_value: Enum.reduce(items, 0.0, fn item, sum -> item.usd_value + sum end)
      }
    end)
    |> Enum.sort_by(& &1.usd_value, :desc)
  end
end
