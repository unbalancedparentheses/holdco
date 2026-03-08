defmodule HoldcoWeb.ExportController do
  use HoldcoWeb, :controller

  alias Holdco.{Corporate, Assets, Banking, Finance, Platform}
  alias Holdco.Finance.Consolidation

  def audit_package(conn, params) do
    company_id = parse_company_id(params)

    trial_balance_csv = generate_trial_balance_csv(company_id)
    journal_entries_csv = generate_journal_entries_csv(company_id)
    audit_log_csv = generate_audit_log_csv()

    files = [
      {~c"trial_balance.csv", trial_balance_csv},
      {~c"journal_entries.csv", journal_entries_csv},
      {~c"audit_log.csv", audit_log_csv}
    ]

    {:ok, {_filename, zip_data}} = :zip.create(~c"audit-package.zip", files, [:memory])

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header("content-disposition", "attachment; filename=\"audit-package.zip\"")
    |> send_resp(200, zip_data)
  end

  def companies(conn, _params) do
    companies = Corporate.list_companies()

    csv =
      [["ID", "Name", "Country", "Category", "Ownership %", "KYC Status"]]
      |> Enum.concat(
        Enum.map(companies, fn c ->
          [c.id, c.name, c.country, c.category, c.ownership_pct, c.kyc_status]
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
      [["ID", "Date", "Description", "Amount", "Currency", "Type", "Company"]]
      |> Enum.concat(
        Enum.map(transactions, fn t ->
          [
            t.id,
            t.date,
            t.description,
            t.amount,
            t.currency,
            t.transaction_type,
            if(t.company, do: t.company.name, else: "")
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "transactions.csv", csv)
  end

  def chart_of_accounts(conn, params) do
    company_id = parse_company_id(params)
    accounts = Finance.list_accounts(company_id)

    csv =
      [["Code", "Name", "Type", "Currency", "Parent", "Company", "External ID"]]
      |> Enum.concat(
        Enum.map(accounts, fn a ->
          [
            a.code,
            a.name,
            a.account_type,
            a.currency,
            if(a.parent, do: a.parent.name, else: ""),
            if(a.company, do: a.company.name, else: ""),
            a.external_id || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "chart-of-accounts.csv", csv)
  end

  def journal_entries(conn, params) do
    company_id = parse_company_id(params)
    entries = Finance.list_journal_entries(company_id)

    csv =
      [["Date", "Reference", "Description", "Company", "Total Debit", "Total Credit", "Lines"]]
      |> Enum.concat(
        Enum.map(entries, fn e ->
          lines = e.lines || []
          total_debit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Decimal.add(acc, l.debit || Decimal.new(0)) end)
          total_credit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Decimal.add(acc, l.credit || Decimal.new(0)) end)

          [
            e.date,
            e.reference || "",
            e.description,
            if(e.company, do: e.company.name, else: ""),
            total_debit,
            total_credit,
            length(lines)
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "journal-entries.csv", csv)
  end

  def financials(conn, params) do
    company_id = parse_company_id(params)
    financials = Finance.list_financials(company_id)

    csv =
      [["Period", "Company", "Revenue", "Expenses", "Net Income", "Currency", "Notes"]]
      |> Enum.concat(
        Enum.map(financials, fn f ->
          net = if f.revenue && f.expenses, do: Decimal.sub(f.revenue, f.expenses), else: Decimal.new(0)

          [
            f.period,
            if(f.company, do: f.company.name, else: ""),
            f.revenue || 0,
            f.expenses || 0,
            net,
            f.currency,
            f.notes || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "financials.csv", csv)
  end

  def consolidated(conn, _params) do
    data = Consolidation.build()
    companies = data.companies
    bs = data.balance_sheet
    is = data.income_statement

    entity_names = Enum.map(companies, & &1.name)

    header = ["Section", "Account"] ++ entity_names ++ ["Elimination", "NCI", "Consolidated"]

    asset_rows = section_rows("Assets", bs.assets, companies)
    asset_total = total_row("Total Assets", bs.assets, companies, data.entity_data, :assets, bs.total_assets)

    liability_rows = section_rows("Liabilities", bs.liabilities, companies)
    liability_total = total_row("Total Liabilities", bs.liabilities, companies, data.entity_data, :liabilities, bs.total_liabilities)

    equity_rows = section_rows("Equity", bs.equity, companies)
    equity_total = total_row("Total Equity", bs.equity, companies, data.entity_data, :equity, bs.total_equity)

    revenue_rows = section_rows("Revenue", is.revenue, companies)
    revenue_total = total_row_is("Total Revenue", is.revenue, companies, data.entity_data, :total_revenue, is.total_revenue)

    expense_rows = section_rows("Expenses", is.expenses, companies)
    expense_total = total_row_is("Total Expenses", is.expenses, companies, data.entity_data, :total_expenses, is.total_expenses)

    net_income_row = ["Income Statement", "Net Income"] ++ List.duplicate("", length(companies)) ++ ["", "", fmt(is.net_income)]

    csv =
      [header]
      |> Enum.concat(asset_rows)
      |> Enum.concat([asset_total, []])
      |> Enum.concat(liability_rows)
      |> Enum.concat([liability_total, []])
      |> Enum.concat(equity_rows)
      |> Enum.concat([equity_total, []])
      |> Enum.concat(revenue_rows)
      |> Enum.concat([revenue_total, []])
      |> Enum.concat(expense_rows)
      |> Enum.concat([expense_total, []])
      |> Enum.concat([net_income_row])
      |> csv_encode()

    send_csv(conn, "consolidated.csv", csv)
  end

  defp section_rows(section, rows, companies) do
    Enum.map(rows, fn row ->
      entity_vals = Enum.map(companies, fn c -> fmt(Map.get(row.by_entity, c.id, 0)) end)
      [section, row.name] ++ entity_vals ++ [fmt(row.elimination), fmt(row.nci), fmt(row.consolidated)]
    end)
  end

  defp total_row(label, rows, companies, entity_data, bs_section, total) do
    entity_vals = Enum.map(companies, fn c -> fmt(Consolidation.entity_bs_total(entity_data, c.id, bs_section)) end)
    elim = fmt(Consolidation.sum_field_list(rows, :elimination))
    nci = fmt(Consolidation.sum_field_list(rows, :nci))
    ["", label] ++ entity_vals ++ [elim, nci, fmt(total)]
  end

  defp total_row_is(label, rows, companies, entity_data, is_field, total) do
    entity_vals = Enum.map(companies, fn c -> fmt(Consolidation.entity_is_total(entity_data, c.id, is_field)) end)
    elim = fmt(Consolidation.sum_field_list(rows, :elimination))
    nci = fmt(Consolidation.sum_field_list(rows, :nci))
    ["", label] ++ entity_vals ++ [elim, nci, fmt(total)]
  end

  defp fmt(%Decimal{} = n), do: Decimal.to_string(Decimal.round(n, 2))
  defp fmt(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp fmt(n) when is_integer(n), do: Integer.to_string(n)
  defp fmt(_), do: "0"

  def audit_log(conn, params) do
    logs = Platform.list_audit_logs(params)

    csv =
      [["ID", "Action", "Table", "Record ID", "User", "Timestamp", "Old Values", "New Values"]]
      |> Enum.concat(
        Enum.map(logs, fn l ->
          [
            l.id,
            l.action,
            l.table_name,
            l.record_id,
            if(l.user, do: l.user.email, else: ""),
            if(l.inserted_at,
              do: Calendar.strftime(l.inserted_at, "%Y-%m-%d %H:%M:%S"),
              else: ""
            ),
            l.old_values || "",
            l.new_values || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "audit-log.csv", csv)
  end

  defp generate_trial_balance_csv(company_id) do
    rows = Finance.trial_balance(company_id)

    [["Code", "Account", "Type", "Debit", "Credit", "Balance"]]
    |> Enum.concat(
      Enum.map(rows, fn r ->
        [r.code, r.name, r.account_type, r.total_debit, r.total_credit, r.balance]
      end)
    )
    |> csv_encode()
  end

  defp generate_journal_entries_csv(company_id) do
    entries = Finance.list_journal_entries(company_id)

    [["Date", "Reference", "Description", "Company", "Total Debit", "Total Credit", "Lines"]]
    |> Enum.concat(
      Enum.map(entries, fn e ->
        lines = e.lines || []
        total_debit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Decimal.add(acc, l.debit || Decimal.new(0)) end)
        total_credit = Enum.reduce(lines, Decimal.new(0), fn l, acc -> Decimal.add(acc, l.credit || Decimal.new(0)) end)

        [
          e.date,
          e.reference || "",
          e.description,
          if(e.company, do: e.company.name, else: ""),
          total_debit,
          total_credit,
          length(lines)
        ]
      end)
    )
    |> csv_encode()
  end

  defp generate_audit_log_csv do
    logs = Platform.list_audit_logs(%{limit: 10_000})

    [["ID", "Action", "Table", "Record ID", "User", "Timestamp", "Old Values", "New Values"]]
    |> Enum.concat(
      Enum.map(logs, fn l ->
        [
          l.id,
          l.action,
          l.table_name,
          l.record_id,
          if(l.user, do: l.user.email, else: ""),
          if(l.inserted_at,
            do: Calendar.strftime(l.inserted_at, "%Y-%m-%d %H:%M:%S"),
            else: ""
          ),
          l.old_values || "",
          l.new_values || ""
        ]
      end)
    )
    |> csv_encode()
  end

  defp parse_company_id(%{"company_id" => ""}), do: nil
  defp parse_company_id(%{"company_id" => id}) when is_binary(id), do: String.to_integer(id)
  defp parse_company_id(_), do: nil

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
