defmodule HoldcoWeb.XbrlController do
  use HoldcoWeb, :controller
  alias Holdco.Finance

  def export(conn, %{"id" => company_id}) do
    company_id = String.to_integer(company_id)
    company = Holdco.Corporate.get_company!(company_id)
    bs = Finance.balance_sheet(company_id)
    is = Finance.income_statement(company_id)

    xml = build_xbrl(company, bs, is)

    conn
    |> put_resp_content_type("application/xml")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{company.name}-xbrl.xml\"")
    |> send_resp(200, xml)
  end

  defp build_xbrl(company, bs, is) do
    today = Date.to_iso8601(Date.utc_today())

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <xbrli:xbrl
      xmlns:xbrli="http://www.xbrl.org/2003/instance"
      xmlns:us-gaap="http://fasb.org/us-gaap/2023"
      xmlns:dei="http://xbrl.sec.gov/dei/2023"
      xmlns:iso4217="http://www.xbrl.org/2003/iso4217">
      <xbrli:context id="current">
        <xbrli:entity><xbrli:identifier scheme="http://www.sec.gov">#{escape_xml(company.name)}</xbrli:identifier></xbrli:entity>
        <xbrli:period><xbrli:instant>#{today}</xbrli:instant></xbrli:period>
      </xbrli:context>
      <xbrli:unit id="USD"><xbrli:measure>iso4217:USD</xbrli:measure></xbrli:unit>
      #{balance_sheet_elements(bs)}
      #{income_statement_elements(is)}
    </xbrli:xbrl>
    """
  end

  # -- Balance Sheet --

  defp balance_sheet_elements(bs) do
    asset_lines = Enum.map(bs.assets, &account_element("us-gaap:Assets", &1))
    liability_lines = Enum.map(bs.liabilities, &account_element("us-gaap:Liabilities", &1))
    equity_lines = Enum.map(bs.equity, &account_element("us-gaap:StockholdersEquity", &1))

    [
      "<us-gaap:Assets contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(bs.total_assets)}</us-gaap:Assets>",
      "<us-gaap:Liabilities contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(bs.total_liabilities)}</us-gaap:Liabilities>",
      "<us-gaap:StockholdersEquity contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(bs.total_equity)}</us-gaap:StockholdersEquity>"
      | asset_lines ++ liability_lines ++ equity_lines
    ]
    |> Enum.join("\n  ")
  end

  # -- Income Statement --

  defp income_statement_elements(is) do
    revenue_lines = Enum.map(is.revenue, &account_element("us-gaap:Revenues", &1))
    expense_lines = Enum.map(is.expenses, &account_element("us-gaap:CostsAndExpenses", &1))

    [
      "<us-gaap:Revenues contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(is.total_revenue)}</us-gaap:Revenues>",
      "<us-gaap:CostsAndExpenses contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(is.total_expenses)}</us-gaap:CostsAndExpenses>",
      "<us-gaap:NetIncomeLoss contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{format_value(is.net_income)}</us-gaap:NetIncomeLoss>"
      | revenue_lines ++ expense_lines
    ]
    |> Enum.join("\n  ")
  end

  # -- Helpers --

  defp account_element(taxonomy_element, account) do
    # Map individual account lines as child elements with descriptive names
    name = escape_xml(account.name || "Unknown")
    balance = format_value(account_balance(account))

    "<!-- #{name} -->\n  " <>
      "<#{taxonomy_element} contextRef=\"current\" unitRef=\"USD\" decimals=\"2\">#{balance}</#{taxonomy_element}>"
  end

  defp account_balance(%{balance: balance}) when is_number(balance), do: balance
  defp account_balance(%{amount: amount}) when is_number(amount), do: amount
  defp account_balance(_), do: 0.0

  defp format_value(n) when is_float(n), do: Float.round(n, 2) |> to_string()
  defp format_value(n) when is_integer(n), do: to_string(n)
  defp format_value(_), do: "0.0"

  defp escape_xml(nil), do: ""

  defp escape_xml(str) when is_binary(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape_xml(other), do: other |> to_string() |> escape_xml()
end
