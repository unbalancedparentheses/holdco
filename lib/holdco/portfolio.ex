defmodule Holdco.Portfolio do
  alias Holdco.{Assets, Banking, Finance, Pricing}

  def calculate_nav do
    holdings = Assets.list_holdings()
    bank_accounts = Banking.list_bank_accounts()
    liabilities = Finance.list_liabilities()

    liquid = Enum.reduce(bank_accounts, 0.0, fn ba, acc ->
      acc + to_usd(ba.balance, ba.currency)
    end)

    {marketable, illiquid} = Enum.reduce(holdings, {0.0, 0.0}, fn h, {mkt, ill} ->
      value = holding_value(h)
      if h.asset_type in ~w(equity crypto commodity) do
        {mkt + value, ill}
      else
        {mkt, ill + value}
      end
    end)

    # Add real estate and fund investments to illiquid
    real_estate = Assets.list_real_estate_properties()
    re_value = Enum.reduce(real_estate, 0.0, fn re, acc ->
      acc + to_usd(re.current_valuation || re.purchase_price || 0.0, re.currency)
    end)

    funds = Assets.list_fund_investments()
    fund_value = Enum.reduce(funds, 0.0, fn f, acc ->
      acc + to_usd(f.nav, f.currency)
    end)

    illiquid = illiquid + re_value + fund_value

    total_liabilities = Enum.reduce(liabilities, 0.0, fn l, acc ->
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
      nil -> 0.0
      "" -> 0.0
      ticker ->
        case Pricing.get_latest_price(ticker) do
          %{price: price} -> to_usd(qty * price, holding.currency)
          nil -> 0.0
        end
    end
  end

  @fx_rates %{"USD" => 1.0, "EUR" => 1.08, "GBP" => 1.27, "ARS" => 0.001, "BRL" => 0.19}

  def to_usd(amount, "USD"), do: amount
  def to_usd(amount, currency) do
    rate = Map.get(@fx_rates, currency, 1.0)
    amount * rate
  end

  def asset_allocation do
    holdings = Assets.list_holdings()
    holdings
    |> Enum.group_by(& &1.asset_type)
    |> Enum.map(fn {type, items} ->
      value = Enum.reduce(items, 0.0, fn h, acc -> acc + holding_value(h) end)
      %{type: type, value: value}
    end)
    |> Enum.sort_by(& &1.value, :desc)
  end

  def fx_exposure do
    bank_accounts = Banking.list_bank_accounts()
    holdings = Assets.list_holdings()

    balances_by_ccy = Enum.group_by(bank_accounts, & &1.currency)
    |> Enum.map(fn {ccy, accs} ->
      total = Enum.reduce(accs, 0.0, fn acc, sum -> acc.balance + sum end)
      %{currency: ccy, amount: total, usd_value: to_usd(total, ccy)}
    end)

    holdings_by_ccy = Enum.group_by(holdings, & &1.currency)
    |> Enum.map(fn {ccy, hs} ->
      total = Enum.reduce(hs, 0.0, fn h, acc -> acc + holding_value(h) end)
      %{currency: ccy, amount: total, usd_value: total}
    end)

    (balances_by_ccy ++ holdings_by_ccy)
    |> Enum.group_by(& &1.currency)
    |> Enum.map(fn {ccy, items} ->
      %{currency: ccy, usd_value: Enum.reduce(items, 0.0, fn item, sum -> item.usd_value + sum end)}
    end)
    |> Enum.sort_by(& &1.usd_value, :desc)
  end
end
