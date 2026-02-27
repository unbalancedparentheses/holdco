defmodule Holdco.AI.DataContext do
  @moduledoc """
  Aggregates portfolio data from existing context modules to build
  the system prompt context for LLM conversations.
  """

  alias Holdco.{Portfolio, Corporate, Banking, Assets, Finance, Compliance}

  def build_summary do
    nav = Portfolio.calculate_nav()
    companies = Corporate.list_companies()
    allocation = Portfolio.asset_allocation()
    deadlines = Compliance.list_tax_deadlines()
    holdings = Assets.list_holdings()
    recent_txns = Banking.list_transactions(%{limit: 20})
    liabilities = Finance.list_liabilities()

    format_as_context(nav, companies, allocation, deadlines, holdings, recent_txns, liabilities)
  end

  defp format_as_context(nav, companies, allocation, deadlines, holdings, recent_txns, liabilities) do
    sections = [
      format_nav(nav),
      format_companies(companies),
      format_allocation(allocation),
      format_holdings(holdings),
      format_liabilities(liabilities),
      format_transactions(recent_txns),
      format_deadlines(deadlines)
    ]

    Enum.join(sections, "\n\n")
  end

  defp format_nav(nav) do
    """
    ## Portfolio Summary (USD)
    - Net Asset Value: $#{format_num(nav.nav)}
    - Liquid (bank balances): $#{format_num(nav.liquid)}
    - Marketable (stocks, crypto): $#{format_num(nav.marketable)}
    - Illiquid (real estate, PE, funds): $#{format_num(nav.illiquid)}
    - Total Liabilities: $#{format_num(nav.liabilities)}
    """
    |> String.trim()
  end

  defp format_companies(companies) do
    lines =
      Enum.map(companies, fn c ->
        "- #{c.name} (#{c.country}, #{c.category || "N/A"}, status: #{c.wind_down_status})"
      end)

    "## Companies (#{length(companies)} entities)\n" <> Enum.join(lines, "\n")
  end

  defp format_allocation(allocation) do
    lines =
      Enum.map(allocation, fn a ->
        "- #{a.type}: #{a.count} holdings, value $#{format_num(a.value)}"
      end)

    "## Asset Allocation\n" <> Enum.join(lines, "\n")
  end

  defp format_holdings(holdings) do
    lines =
      Enum.take(holdings, 30)
      |> Enum.map(fn h ->
        "- #{h.asset} (#{h.asset_type}, #{h.ticker || "no ticker"}): #{h.quantity} units"
      end)

    "## Holdings (#{length(holdings)} total, showing first 30)\n" <> Enum.join(lines, "\n")
  end

  defp format_liabilities(liabilities) do
    lines =
      Enum.map(liabilities, fn l ->
        "- #{l.creditor}: $#{format_num(l.principal)} #{l.currency} (#{l.status}, rate: #{l.interest_rate || "N/A"}%)"
      end)

    "## Liabilities (#{length(liabilities)})\n" <> Enum.join(lines, "\n")
  end

  defp format_transactions(txns) do
    lines =
      Enum.map(txns, fn tx ->
        "- #{tx.date}: #{tx.transaction_type} — #{tx.description} #{tx.amount} #{tx.currency}"
      end)

    "## Recent Transactions (last 20)\n" <> Enum.join(lines, "\n")
  end

  defp format_deadlines(deadlines) do
    upcoming =
      deadlines
      |> Enum.filter(&(&1.status in ["pending", "overdue"]))
      |> Enum.take(10)

    lines =
      Enum.map(upcoming, fn td ->
        "- #{td.due_date}: #{td.description} (#{td.status})"
      end)

    "## Upcoming Tax Deadlines\n" <> Enum.join(lines, "\n")
  end

  defp format_num(nil), do: "0"
  defp format_num(%Decimal{} = d), do: Decimal.round(d, 2) |> Decimal.to_string()
  defp format_num(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp format_num(n) when is_integer(n), do: Integer.to_string(n)
  defp format_num(n), do: to_string(n)
end
