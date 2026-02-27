defmodule Holdco.Tax.CapitalGains do
  @moduledoc """
  Capital gains tax computation using FIFO, LIFO, or specific-lot identification.
  """

  alias Holdco.{Assets, Portfolio}
  alias Holdco.Money

  def compute(method \\ :fifo) do
    holdings = Assets.list_holdings()

    holdings
    |> Enum.map(fn holding ->
      lots = holding.cost_basis_lots || []
      current_price = current_price_for(holding)

      {short_term, long_term} = classify_gains(lots, current_price, method)

      total = Money.add(
        Money.add(short_term.realized, long_term.realized),
        Money.add(short_term.unrealized, long_term.unrealized)
      )

      %{
        holding_id: holding.id,
        asset: holding.asset,
        ticker: holding.ticker,
        company: if(holding.company, do: holding.company.name, else: ""),
        short_term_realized: short_term.realized,
        long_term_realized: long_term.realized,
        short_term_unrealized: short_term.unrealized,
        long_term_unrealized: long_term.unrealized,
        total_gain: total
      }
    end)
    |> Enum.filter(fn r -> not Money.zero?(r.total_gain) end)
  end

  defp current_price_for(holding) do
    value = Portfolio.holding_value(holding)

    if Money.zero?(value) do
      Decimal.new(0)
    else
      qty = Money.to_decimal(holding.quantity)
      if Money.gt?(qty, 0), do: Money.div(value, qty), else: Decimal.new(0)
    end
  end

  defp classify_gains(lots, current_price, method) do
    sorted_lots = sort_lots(lots, method)
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)
    zero = Decimal.new(0)

    {short_realized, long_realized, short_unrealized, long_unrealized} =
      Enum.reduce(sorted_lots, {zero, zero, zero, zero}, fn lot, {sr, lr, su, lu} ->
        purchase_date = parse_date(lot.purchase_date)
        is_long_term = purchase_date != nil and Date.compare(purchase_date, one_year_ago) == :lt
        cost_per_unit = Money.to_decimal(lot.price_per_unit)
        sold_qty = Money.to_decimal(lot.sold_quantity)
        remaining = Money.sub(Money.to_decimal(lot.quantity), sold_qty)

        realized =
          if Money.gt?(sold_qty, 0) do
            proceeds = Money.mult(sold_qty, Money.to_decimal(lot.sold_price))
            cost = Money.mult(sold_qty, cost_per_unit)
            Money.sub(proceeds, cost)
          else
            zero
          end

        unrealized =
          if Money.gt?(remaining, 0) do
            Money.mult(remaining, Money.sub(current_price, cost_per_unit))
          else
            zero
          end

        if is_long_term do
          {sr, Money.add(lr, realized), su, Money.add(lu, unrealized)}
        else
          {Money.add(sr, realized), lr, Money.add(su, unrealized), lu}
        end
      end)

    {
      %{realized: short_realized, unrealized: short_unrealized},
      %{realized: long_realized, unrealized: long_unrealized}
    }
  end

  defp sort_lots(lots, :fifo), do: Enum.sort_by(lots, & &1.purchase_date)
  defp sort_lots(lots, :lifo), do: Enum.sort_by(lots, & &1.purchase_date, :desc)
  defp sort_lots(lots, _specific), do: lots

  defp parse_date(nil), do: nil

  defp parse_date(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
