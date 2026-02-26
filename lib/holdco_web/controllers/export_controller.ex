defmodule HoldcoWeb.ExportController do
  use HoldcoWeb, :controller

  alias Holdco.{Corporate, Assets, Banking, Finance}

  def companies(conn, _params) do
    companies = Corporate.list_companies()

    csv =
      [["ID", "Name", "Country", "Entity Type", "Category", "Ownership %", "KYC Status"]]
      |> Enum.concat(
        Enum.map(companies, fn c ->
          [c.id, c.name, c.country, c.entity_type, c.category, c.ownership_pct, c.kyc_status]
        end)
      )
      |> csv_encode()

    send_csv(conn, "companies.csv", csv)
  end

  def holdings(conn, _params) do
    holdings = Assets.list_holdings()

    csv =
      [["ID", "Asset", "Ticker", "Type", "Quantity", "Currency", "Company"]]
      |> Enum.concat(
        Enum.map(holdings, fn h ->
          [
            h.id,
            h.asset,
            h.ticker,
            h.asset_type,
            h.quantity,
            h.currency,
            if(h.company, do: h.company.name, else: "")
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "holdings.csv", csv)
  end

  def transactions(conn, _params) do
    transactions = Banking.list_transactions()

    csv =
      [["ID", "Date", "Description", "Amount", "Currency", "Category", "Company"]]
      |> Enum.concat(
        Enum.map(transactions, fn t ->
          [
            t.id,
            t.date,
            t.description,
            t.amount,
            t.currency,
            t.category,
            if(t.company, do: t.company.name, else: "")
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "transactions.csv", csv)
  end

  def chart_of_accounts(conn, _params) do
    accounts = Finance.list_accounts()

    csv =
      [["Code", "Name", "Type", "Currency", "Parent", "External ID"]]
      |> Enum.concat(
        Enum.map(accounts, fn a ->
          [
            a.code,
            a.name,
            a.account_type,
            a.currency,
            if(a.parent, do: a.parent.name, else: ""),
            a.external_id || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "chart-of-accounts.csv", csv)
  end

  def journal_entries(conn, _params) do
    entries = Finance.list_journal_entries()

    csv =
      [["Date", "Reference", "Description", "Total Debit", "Total Credit", "Lines"]]
      |> Enum.concat(
        Enum.map(entries, fn e ->
          lines = e.lines || []
          total_debit = Enum.reduce(lines, 0.0, &((&1.debit || 0.0) + &2))
          total_credit = Enum.reduce(lines, 0.0, &((&1.credit || 0.0) + &2))

          [
            e.date,
            e.reference || "",
            e.description,
            total_debit,
            total_credit,
            length(lines)
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "journal-entries.csv", csv)
  end

  defp csv_encode(rows) do
    rows
    |> Enum.map(fn row ->
      row
      |> Enum.map(fn
        nil -> ""
        val -> val |> to_string() |> csv_escape()
      end)
      |> Enum.join(",")
    end)
    |> Enum.join("\r\n")
  end

  defp csv_escape(val) do
    if String.contains?(val, [",", "\"", "\n"]) do
      "\"" <> String.replace(val, "\"", "\"\"") <> "\""
    else
      val
    end
  end

  defp send_csv(conn, filename, csv) do
    conn
    |> put_resp_content_type("text/csv")
    |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
    |> send_resp(200, csv)
  end
end
