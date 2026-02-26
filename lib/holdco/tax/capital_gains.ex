defmodule Holdco.Tax.CapitalGains do
  @moduledoc """
  Capital gains tax computation using FIFO, LIFO, or specific-lot identification.
  """

  alias Holdco.{Assets, Portfolio}

  def compute(method \\ :fifo) do
    holdings = Assets.list_holdings()

    holdings
    |> Enum.map(fn holding ->
      lots = holding.cost_basis_lots || []
      current_price = current_price_for(holding)

      {short_term, long_term} = classify_gains(lots, current_price, method)

      %{
        holding_id: holding.id,
        asset: holding.asset,
        ticker: holding.ticker,
        company: if(holding.company, do: holding.company.name, else: ""),
        short_term_realized: short_term.realized,
        long_term_realized: long_term.realized,
        short_term_unrealized: short_term.unrealized,
        long_term_unrealized: long_term.unrealized,
        total_gain: short_term.realized + long_term.realized + short_term.unrealized + long_term.unrealized
      }
    end)
    |> Enum.filter(fn r -> r.total_gain != 0.0 end)
  end

  defp current_price_for(holding) do
    value = Portfolio.holding_value(holding)

    if value == 0.0 do
      0.0
    else
      qty = holding.quantity || 1.0
      if qty > 0, do: value / qty, else: 0.0
    end
  end

  defp classify_gains(lots, current_price, method) do
    sorted_lots = sort_lots(lots, method)
    today = Date.utc_today()
    one_year_ago = Date.add(today, -365)

    {short_realized, long_realized, short_unrealized, long_unrealized} =
      Enum.reduce(sorted_lots, {0.0, 0.0, 0.0, 0.0}, fn lot, {sr, lr, su, lu} ->
        purchase_date = parse_date(lot.purchase_date)
        is_long_term = purchase_date != nil and Date.compare(purchase_date, one_year_ago) == :lt
        cost_per_unit = lot.price_per_unit || 0.0
        sold_qty = lot.sold_quantity || 0.0
        remaining = (lot.quantity || 0.0) - sold_qty

        # Realized gains from sold portions
        realized =
          if sold_qty > 0 do
            proceeds = sold_qty * (lot.sold_price || 0.0)
            cost = sold_qty * cost_per_unit
            proceeds - cost
          else
            0.0
          end

        # Unrealized gains from remaining lots
        unrealized =
          if remaining > 0 do
            remaining * (current_price - cost_per_unit)
          else
            0.0
          end

        if is_long_term do
          {sr, lr + realized, su, lu + unrealized}
        else
          {sr + realized, lr, su + unrealized, lu}
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
