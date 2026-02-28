defmodule HoldcoWeb.TaxExportController do
  use HoldcoWeb, :controller

  alias Holdco.{Finance, Compliance, Corporate}

  def tax_provisions_csv(conn, params) do
    company_id = parse_company_id(params)
    tax_payments = Finance.list_tax_payments(company_id)

    csv =
      [["ID", "Company", "Jurisdiction", "Tax Type", "Amount", "Currency", "Date", "Period", "Status", "Notes"]]
      |> Enum.concat(
        Enum.map(tax_payments, fn tp ->
          [
            tp.id,
            if(tp.company, do: tp.company.name, else: ""),
            tp.jurisdiction,
            tp.tax_type,
            tp.amount,
            tp.currency || "USD",
            tp.date,
            tp.period || "",
            tp.status || "",
            tp.notes || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "tax-provisions.csv", csv)
  end

  def deferred_taxes_csv(conn, params) do
    company_id = parse_company_id(params)
    # Deferred taxes derived from tax payments grouped by jurisdiction and type
    tax_payments = Finance.list_tax_payments(company_id)

    by_jurisdiction =
      tax_payments
      |> Enum.group_by(fn tp -> {tp.jurisdiction, tp.tax_type} end)
      |> Enum.map(fn {{jurisdiction, tax_type}, payments} ->
        total = Enum.reduce(payments, Decimal.new(0), fn tp, acc ->
          Decimal.add(acc, tp.amount || Decimal.new(0))
        end)
        company_names =
          payments
          |> Enum.map(fn tp -> if tp.company, do: tp.company.name, else: "" end)
          |> Enum.uniq()
          |> Enum.join("; ")

        %{
          jurisdiction: jurisdiction,
          tax_type: tax_type,
          total_amount: total,
          payment_count: length(payments),
          companies: company_names
        }
      end)
      |> Enum.sort_by(& &1.jurisdiction)

    csv =
      [["Jurisdiction", "Tax Type", "Total Amount", "Payment Count", "Companies"]]
      |> Enum.concat(
        Enum.map(by_jurisdiction, fn row ->
          [
            row.jurisdiction,
            row.tax_type,
            row.total_amount,
            row.payment_count,
            row.companies
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "deferred-taxes.csv", csv)
  end

  def withholding_reclaims_csv(conn, params) do
    company_id = parse_company_id(params)
    withholdings = Compliance.list_withholding_taxes(company_id)

    csv =
      [["ID", "Company", "Payment Type", "Country From", "Country To", "Gross Amount", "Rate", "Tax Amount", "Currency", "Date", "Notes"]]
      |> Enum.concat(
        Enum.map(withholdings, fn wt ->
          [
            wt.id,
            if(wt.company, do: wt.company.name, else: ""),
            wt.payment_type,
            wt.country_from,
            wt.country_to,
            wt.gross_amount,
            wt.rate,
            wt.tax_amount,
            wt.currency || "USD",
            wt.date,
            wt.notes || ""
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "withholding-reclaims.csv", csv)
  end

  def k1_reports_csv(conn, params) do
    company_id = parse_company_id(params)
    # K-1 reports derived from capital contributions and dividends
    companies =
      if company_id do
        [Corporate.get_company!(company_id)]
      else
        Corporate.list_companies()
      end

    rows =
      Enum.flat_map(companies, fn company ->
        dividends = Finance.list_dividends(company.id)
        contributions = Finance.list_capital_contributions(company.id)

        total_dividends =
          Enum.reduce(dividends, Decimal.new(0), fn d, acc ->
            Decimal.add(acc, d.amount || Decimal.new(0))
          end)

        total_contributions =
          Enum.reduce(contributions, Decimal.new(0), fn cc, acc ->
            Decimal.add(acc, cc.amount || Decimal.new(0))
          end)

        if Decimal.equal?(total_dividends, 0) and Decimal.equal?(total_contributions, 0) do
          []
        else
          [%{
            company: company.name,
            country: company.country,
            ownership_pct: company.ownership_pct || 0,
            total_dividends: total_dividends,
            total_contributions: total_contributions,
            net_income_share: Decimal.sub(total_dividends, total_contributions)
          }]
        end
      end)

    csv =
      [["Company", "Country", "Ownership %", "Total Dividends", "Total Contributions", "Net Income Share"]]
      |> Enum.concat(
        Enum.map(rows, fn r ->
          [
            r.company,
            r.country,
            r.ownership_pct,
            r.total_dividends,
            r.total_contributions,
            r.net_income_share
          ]
        end)
      )
      |> csv_encode()

    send_csv(conn, "k1-reports.csv", csv)
  end

  def tax_package_zip(conn, params) do
    provisions_csv = generate_provisions_csv(params)
    deferred_csv = generate_deferred_csv(params)
    withholding_csv = generate_withholding_csv(params)
    k1_csv = generate_k1_csv(params)

    files = [
      {~c"tax-provisions.csv", provisions_csv},
      {~c"deferred-taxes.csv", deferred_csv},
      {~c"withholding-reclaims.csv", withholding_csv},
      {~c"k1-reports.csv", k1_csv}
    ]

    {:ok, {_filename, zip_data}} = :zip.create(~c"tax-package.zip", files, [:memory])

    conn
    |> put_resp_content_type("application/zip")
    |> put_resp_header("content-disposition", "attachment; filename=\"tax-package.zip\"")
    |> send_resp(200, zip_data)
  end

  # -- Private helpers for ZIP generation --

  defp generate_provisions_csv(params) do
    company_id = parse_company_id(params)
    tax_payments = Finance.list_tax_payments(company_id)

    [["ID", "Company", "Jurisdiction", "Tax Type", "Amount", "Currency", "Date", "Period", "Status", "Notes"]]
    |> Enum.concat(
      Enum.map(tax_payments, fn tp ->
        [
          tp.id,
          if(tp.company, do: tp.company.name, else: ""),
          tp.jurisdiction,
          tp.tax_type,
          tp.amount,
          tp.currency || "USD",
          tp.date,
          tp.period || "",
          tp.status || "",
          tp.notes || ""
        ]
      end)
    )
    |> csv_encode()
  end

  defp generate_deferred_csv(params) do
    company_id = parse_company_id(params)
    tax_payments = Finance.list_tax_payments(company_id)

    by_jurisdiction =
      tax_payments
      |> Enum.group_by(fn tp -> {tp.jurisdiction, tp.tax_type} end)
      |> Enum.map(fn {{jurisdiction, tax_type}, payments} ->
        total = Enum.reduce(payments, Decimal.new(0), fn tp, acc ->
          Decimal.add(acc, tp.amount || Decimal.new(0))
        end)
        company_names =
          payments
          |> Enum.map(fn tp -> if tp.company, do: tp.company.name, else: "" end)
          |> Enum.uniq()
          |> Enum.join("; ")

        %{jurisdiction: jurisdiction, tax_type: tax_type, total_amount: total, payment_count: length(payments), companies: company_names}
      end)
      |> Enum.sort_by(& &1.jurisdiction)

    [["Jurisdiction", "Tax Type", "Total Amount", "Payment Count", "Companies"]]
    |> Enum.concat(
      Enum.map(by_jurisdiction, fn row ->
        [row.jurisdiction, row.tax_type, row.total_amount, row.payment_count, row.companies]
      end)
    )
    |> csv_encode()
  end

  defp generate_withholding_csv(params) do
    company_id = parse_company_id(params)
    withholdings = Compliance.list_withholding_taxes(company_id)

    [["ID", "Company", "Payment Type", "Country From", "Country To", "Gross Amount", "Rate", "Tax Amount", "Currency", "Date", "Notes"]]
    |> Enum.concat(
      Enum.map(withholdings, fn wt ->
        [
          wt.id,
          if(wt.company, do: wt.company.name, else: ""),
          wt.payment_type,
          wt.country_from,
          wt.country_to,
          wt.gross_amount,
          wt.rate,
          wt.tax_amount,
          wt.currency || "USD",
          wt.date,
          wt.notes || ""
        ]
      end)
    )
    |> csv_encode()
  end

  defp generate_k1_csv(params) do
    company_id = parse_company_id(params)

    companies =
      if company_id do
        [Corporate.get_company!(company_id)]
      else
        Corporate.list_companies()
      end

    rows =
      Enum.flat_map(companies, fn company ->
        dividends = Finance.list_dividends(company.id)
        contributions = Finance.list_capital_contributions(company.id)

        total_dividends =
          Enum.reduce(dividends, Decimal.new(0), fn d, acc ->
            Decimal.add(acc, d.amount || Decimal.new(0))
          end)

        total_contributions =
          Enum.reduce(contributions, Decimal.new(0), fn cc, acc ->
            Decimal.add(acc, cc.amount || Decimal.new(0))
          end)

        if Decimal.equal?(total_dividends, 0) and Decimal.equal?(total_contributions, 0) do
          []
        else
          [%{
            company: company.name,
            country: company.country,
            ownership_pct: company.ownership_pct || 0,
            total_dividends: total_dividends,
            total_contributions: total_contributions,
            net_income_share: Decimal.sub(total_dividends, total_contributions)
          }]
        end
      end)

    [["Company", "Country", "Ownership %", "Total Dividends", "Total Contributions", "Net Income Share"]]
    |> Enum.concat(
      Enum.map(rows, fn r ->
        [r.company, r.country, r.ownership_pct, r.total_dividends, r.total_contributions, r.net_income_share]
      end)
    )
    |> csv_encode()
  end

  # -- Shared helpers --

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
