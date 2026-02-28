defmodule HoldcoWeb.ReportHTML do
  use HoldcoWeb, :html

  defp report_css do
    """
    *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
      font-size: 11px;
      line-height: 1.5;
      color: #1a1a1a;
      background: #fff;
      padding: 2rem;
      max-width: 1000px;
      margin: 0 auto;
    }
    .report-header {
      border-bottom: 3px solid #0d7680;
      padding-bottom: 1rem;
      margin-bottom: 1.5rem;
    }
    .report-header h1 {
      font-family: 'Source Serif 4', Georgia, serif;
      font-size: 22px;
      font-weight: 700;
      color: #0d7680;
      margin-bottom: 0.25rem;
    }
    .report-meta {
      display: flex;
      justify-content: space-between;
      color: #666;
      font-size: 10px;
    }
    .section { margin-bottom: 1.5rem; }
    .section h2 {
      font-family: 'Source Serif 4', Georgia, serif;
      font-size: 15px;
      font-weight: 600;
      color: #333;
      border-bottom: 1px solid #ddd;
      padding-bottom: 0.35rem;
      margin-bottom: 0.75rem;
    }
    .section h3 {
      font-size: 12px;
      font-weight: 600;
      color: #555;
      margin-bottom: 0.5rem;
      margin-top: 0.75rem;
    }
    table {
      width: 100%;
      border-collapse: collapse;
      margin-bottom: 1rem;
      font-size: 10.5px;
    }
    thead th {
      background: #f5f5f5;
      border-bottom: 2px solid #ccc;
      padding: 6px 8px;
      text-align: left;
      font-weight: 600;
      font-size: 10px;
      text-transform: uppercase;
      letter-spacing: 0.03em;
      color: #555;
    }
    thead th.num { text-align: right; }
    tbody td {
      padding: 5px 8px;
      border-bottom: 1px solid #eee;
      vertical-align: top;
    }
    tbody td.num {
      text-align: right;
      font-variant-numeric: tabular-nums;
      font-family: 'JetBrains Mono', monospace;
      font-size: 10px;
    }
    tbody tr:nth-child(even) { background: #fafafa; }
    .summary-grid {
      display: grid;
      grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
      gap: 1rem;
      margin-bottom: 1.5rem;
    }
    .summary-card {
      border: 1px solid #ddd;
      border-radius: 4px;
      padding: 0.75rem 1rem;
      background: #fafafa;
    }
    .summary-card .label {
      font-size: 9px;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: #888;
      margin-bottom: 0.25rem;
    }
    .summary-card .value {
      font-size: 18px;
      font-weight: 700;
      color: #1a1a1a;
      font-variant-numeric: tabular-nums;
    }
    .summary-card .value.positive { color: #00994d; }
    .summary-card .value.negative { color: #cc0000; }
    .tag {
      display: inline-block;
      padding: 1px 6px;
      border-radius: 3px;
      font-size: 9px;
      font-weight: 600;
      text-transform: uppercase;
    }
    .tag-pending { background: #fff3cd; color: #856404; }
    .tag-filed, .tag-completed, .tag-active { background: #d4edda; color: #155724; }
    .tag-overdue { background: #f8d7da; color: #721c24; }
    .tag-default { background: #e9ecef; color: #495057; }
    .footer-note {
      margin-top: 2rem;
      padding-top: 0.75rem;
      border-top: 1px solid #ddd;
      font-size: 9px;
      color: #999;
      text-align: center;
    }
    .totals-row td {
      font-weight: 700;
      border-top: 2px solid #333;
      border-bottom: none;
      background: #f5f5f5;
    }
    @media print {
      body { padding: 0; font-size: 10px; }
      .section { page-break-inside: avoid; }
      table { font-size: 9.5px; }
      thead th { background: #f0f0f0 !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      tbody tr:nth-child(even) { background: #fafafa !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .summary-card { background: #fafafa !important; -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .tag { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
      .no-print { display: none; }
    }
    .print-button {
      position: fixed;
      top: 1rem;
      right: 1rem;
      background: #0d7680;
      color: #fff;
      border: none;
      padding: 8px 16px;
      border-radius: 4px;
      cursor: pointer;
      font-size: 12px;
      font-weight: 600;
      z-index: 100;
    }
    .print-button:hover { background: #0a5f67; }
    """
  end

  def portfolio(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Portfolio NAV Report - Holdco</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,600;8..60,700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
        <style>
          <%= raw(report_css()) %>
        </style>
      </head>
      <body>
        <button class="print-button no-print" onclick="window.print()">Print / Save as PDF</button>

        <div class="report-header">
          <h1>Portfolio NAV Report</h1>
          <div class="report-meta">
            <span>Holdco</span>
            <span>Generated: {Calendar.strftime(@generated_at, "%B %-d, %Y at %H:%M UTC")}</span>
          </div>
        </div>

        <div class="section">
          <h2>Net Asset Value Breakdown</h2>
          <div class="summary-grid">
            <div class="summary-card">
              <div class="label">Net Asset Value</div>
              <div class="value">{format_usd(@nav.nav)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Liquid Assets</div>
              <div class="value">{format_usd(@nav.liquid)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Marketable Securities</div>
              <div class="value">{format_usd(@nav.marketable)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Illiquid Assets</div>
              <div class="value">{format_usd(@nav.illiquid)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Total Liabilities</div>
              <div class="value negative">{format_usd(@nav.liabilities)}</div>
            </div>
          </div>
        </div>

        <div class="section">
          <h2>Asset Allocation</h2>
          <table>
            <thead>
              <tr>
                <th>Asset Type</th>
                <th class="num">Positions</th>
                <th class="num">Value (USD)</th>
                <th class="num">% of Total</th>
              </tr>
            </thead>
            <tbody>
              <% total_alloc = Enum.reduce(@allocation, Decimal.new(0), fn a, acc -> Decimal.add(acc, Holdco.Money.to_decimal(a.value)) end) %>
              <%= for alloc <- @allocation do %>
                <tr>
                  <td>{alloc.type}</td>
                  <td class="num">{alloc.count}</td>
                  <td class="num">{format_usd(alloc.value)}</td>
                  <td class="num">{format_pct(alloc.value, total_alloc)}</td>
                </tr>
              <% end %>
              <tr class="totals-row">
                <td>Total</td>
                <td class="num">{Enum.reduce(@allocation, 0, fn a, acc -> acc + a.count end)}</td>
                <td class="num">{format_usd(total_alloc)}</td>
                <td class="num">100.0%</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="section">
          <h2>FX Exposure</h2>
          <table>
            <thead>
              <tr>
                <th>Currency</th>
                <th class="num">USD Value</th>
                <th class="num">% of Total</th>
              </tr>
            </thead>
            <tbody>
              <% total_fx = Enum.reduce(@fx_exposure, Decimal.new(0), fn f, acc -> Decimal.add(acc, Holdco.Money.to_decimal(f.usd_value)) end) %>
              <%= for fx <- @fx_exposure do %>
                <tr>
                  <td>{fx.currency}</td>
                  <td class="num">{format_usd(fx.usd_value)}</td>
                  <td class="num">{format_pct(fx.usd_value, total_fx)}</td>
                </tr>
              <% end %>
              <tr class="totals-row">
                <td>Total</td>
                <td class="num">{format_usd(total_fx)}</td>
                <td class="num">100.0%</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="section">
          <h2>Gains Summary</h2>
          <div class="summary-grid">
            <div class="summary-card">
              <div class="label">Total Unrealized Gain</div>
              <div class={"value #{gain_class(@gains.aggregate.total_unrealized)}"}>
                {format_usd(@gains.aggregate.total_unrealized)}
              </div>
            </div>
            <div class="summary-card">
              <div class="label">Total Realized Gain</div>
              <div class={"value #{gain_class(@gains.aggregate.total_realized)}"}>
                {format_usd(@gains.aggregate.total_realized)}
              </div>
            </div>
            <div class="summary-card">
              <div class="label">Total Gain</div>
              <div class={"value #{gain_class(@gains.aggregate.total_gain)}"}>
                {format_usd(@gains.aggregate.total_gain)}
              </div>
            </div>
          </div>

          <h3>Per-Holding Detail</h3>
          <table>
            <thead>
              <tr>
                <th>Asset</th>
                <th>Ticker</th>
                <th class="num">Current Value</th>
                <th class="num">Cost Basis</th>
                <th class="num">Unrealized</th>
                <th class="num">Realized</th>
                <th class="num">Total Gain</th>
              </tr>
            </thead>
            <tbody>
              <%= for h <- @gains.per_holding do %>
                <tr>
                  <td>{h.asset}</td>
                  <td>{h.ticker}</td>
                  <td class="num">{format_usd(h.current_value)}</td>
                  <td class="num">{format_usd(h.cost_basis)}</td>
                  <td class="num">{format_usd(h.unrealized_gain)}</td>
                  <td class="num">{format_usd(h.realized_gain)}</td>
                  <td class="num">{format_usd(h.total_gain)}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="footer-note">
          This report was generated automatically by Holdco. All values are in USD unless otherwise noted.
        </div>
      </body>
    </html>
    """
  end

  def financial(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Financial Summary Report - Holdco</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,600;8..60,700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
        <style>
          <%= raw(report_css()) %>
        </style>
      </head>
      <body>
        <button class="print-button no-print" onclick="window.print()">Print / Save as PDF</button>

        <div class="report-header">
          <h1>Financial Summary Report</h1>
          <div class="report-meta">
            <span>Holdco</span>
            <span>Generated: {Calendar.strftime(@generated_at, "%B %-d, %Y at %H:%M UTC")}</span>
          </div>
        </div>

        <div class="section">
          <h2>Consolidated Summary</h2>
          <div class="summary-grid">
            <div class="summary-card">
              <div class="label">Total Revenue</div>
              <div class="value positive">{format_usd(@total_revenue)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Total Expenses</div>
              <div class="value negative">{format_usd(@total_expenses)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Net Income</div>
              <div class={"value #{gain_class(Decimal.sub(Holdco.Money.to_decimal(@total_revenue), Holdco.Money.to_decimal(@total_expenses)))}"}>
                {format_usd(Decimal.sub(Holdco.Money.to_decimal(@total_revenue), Holdco.Money.to_decimal(@total_expenses)))}
              </div>
            </div>
            <div class="summary-card">
              <div class="label">Total Liabilities</div>
              <div class="value negative">{format_usd(@total_liabilities)}</div>
            </div>
          </div>
        </div>

        <div class="section">
          <h2>P&L by Company</h2>
          <%= for {company_name, records} <- @financials_by_company do %>
            <h3>{company_name}</h3>
            <table>
              <thead>
                <tr>
                  <th>Period</th>
                  <th class="num">Revenue</th>
                  <th class="num">Expenses</th>
                  <th class="num">Net</th>
                  <th>Currency</th>
                  <th>Notes</th>
                </tr>
              </thead>
              <tbody>
                <% company_revenue =
                  Enum.reduce(records, Decimal.new(0), fn f, acc -> Decimal.add(acc, f.revenue || Decimal.new(0)) end) %>
                <% company_expenses =
                  Enum.reduce(records, Decimal.new(0), fn f, acc -> Decimal.add(acc, f.expenses || Decimal.new(0)) end) %>
                <%= for f <- records do %>
                  <tr>
                    <td>{f.period}</td>
                    <td class="num">{format_usd(f.revenue || Decimal.new(0))}</td>
                    <td class="num">{format_usd(f.expenses || Decimal.new(0))}</td>
                    <td class="num">{format_usd(Decimal.sub(f.revenue || Decimal.new(0), f.expenses || Decimal.new(0)))}</td>
                    <td>{f.currency}</td>
                    <td>{f.notes}</td>
                  </tr>
                <% end %>
                <tr class="totals-row">
                  <td>Subtotal</td>
                  <td class="num">{format_usd(company_revenue)}</td>
                  <td class="num">{format_usd(company_expenses)}</td>
                  <td class="num">{format_usd(Decimal.sub(company_revenue, company_expenses))}</td>
                  <td></td>
                  <td></td>
                </tr>
              </tbody>
            </table>
          <% end %>
        </div>

        <div class="section">
          <h2>Liabilities</h2>
          <table>
            <thead>
              <tr>
                <th>Creditor</th>
                <th>Type</th>
                <th>Company</th>
                <th class="num">Principal</th>
                <th>Currency</th>
                <th class="num">Interest Rate</th>
                <th>Maturity Date</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for l <- @liabilities do %>
                <tr>
                  <td>{l.creditor}</td>
                  <td>{l.liability_type}</td>
                  <td>{if l.company, do: l.company.name, else: "-"}</td>
                  <td class="num">{format_usd(l.principal || Decimal.new(0))}</td>
                  <td>{l.currency}</td>
                  <td class="num">{if l.interest_rate, do: "#{l.interest_rate}%", else: "-"}</td>
                  <td>{l.maturity_date || "-"}</td>
                  <td><span class={"tag #{status_tag(l.status)}"}>{l.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="footer-note">
          This report was generated automatically by Holdco. All values are in USD unless otherwise noted.
        </div>
      </body>
    </html>
    """
  end

  def compliance(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Compliance Status Report - Holdco</title>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
        <link
          href="https://fonts.googleapis.com/css2?family=Source+Serif+4:opsz,wght@8..60,400;8..60,600;8..60,700&family=Inter:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet"
        />
        <style>
          <%= raw(report_css()) %>
        </style>
      </head>
      <body>
        <button class="print-button no-print" onclick="window.print()">Print / Save as PDF</button>

        <div class="report-header">
          <h1>Compliance Status Report</h1>
          <div class="report-meta">
            <span>Holdco</span>
            <span>Generated: {Calendar.strftime(@generated_at, "%B %-d, %Y at %H:%M UTC")}</span>
          </div>
        </div>

        <div class="section">
          <h2>Overview</h2>
          <div class="summary-grid">
            <div class="summary-card">
              <div class="label">Tax Deadlines</div>
              <div class="value">{length(@tax_deadlines)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Pending Tax Deadlines</div>
              <div class={"value #{if pending_count(@tax_deadlines) > 0, do: "negative", else: "positive"}"}>
                {pending_count(@tax_deadlines)}
              </div>
            </div>
            <div class="summary-card">
              <div class="label">Regulatory Filings</div>
              <div class="value">{length(@regulatory_filings)}</div>
            </div>
            <div class="summary-card">
              <div class="label">Insurance Policies</div>
              <div class="value">{length(@insurance_policies)}</div>
            </div>
          </div>
        </div>

        <div class="section">
          <h2>Upcoming Tax Deadlines</h2>
          <table>
            <thead>
              <tr>
                <th>Company</th>
                <th>Jurisdiction</th>
                <th>Description</th>
                <th>Due Date</th>
                <th>Status</th>
                <th>Notes</th>
              </tr>
            </thead>
            <tbody>
              <%= for td <- @tax_deadlines do %>
                <tr>
                  <td>{if td.company, do: td.company.name, else: "-"}</td>
                  <td>{td.jurisdiction}</td>
                  <td>{td.description}</td>
                  <td class="num">{td.due_date}</td>
                  <td><span class={"tag #{compliance_status_tag(td.status)}"}>{td.status}</span></td>
                  <td>{td.notes}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="section">
          <h2>Regulatory Filings</h2>
          <table>
            <thead>
              <tr>
                <th>Company</th>
                <th>Jurisdiction</th>
                <th>Filing Type</th>
                <th>Due Date</th>
                <th>Filed Date</th>
                <th>Status</th>
                <th>Reference #</th>
              </tr>
            </thead>
            <tbody>
              <%= for rf <- @regulatory_filings do %>
                <tr>
                  <td>{if rf.company, do: rf.company.name, else: "-"}</td>
                  <td>{rf.jurisdiction}</td>
                  <td>{rf.filing_type}</td>
                  <td class="num">{rf.due_date}</td>
                  <td class="num">{rf.filed_date || "-"}</td>
                  <td><span class={"tag #{compliance_status_tag(rf.status)}"}>{rf.status}</span></td>
                  <td>{rf.reference_number || "-"}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="section">
          <h2>Insurance Policies</h2>
          <table>
            <thead>
              <tr>
                <th>Company</th>
                <th>Policy Type</th>
                <th>Provider</th>
                <th>Policy #</th>
                <th class="num">Coverage</th>
                <th class="num">Premium</th>
                <th>Currency</th>
                <th>Start Date</th>
                <th>Expiry Date</th>
              </tr>
            </thead>
            <tbody>
              <%= for ip <- @insurance_policies do %>
                <tr>
                  <td>{if ip.company, do: ip.company.name, else: "-"}</td>
                  <td>{ip.policy_type}</td>
                  <td>{ip.provider}</td>
                  <td>{ip.policy_number || "-"}</td>
                  <td class="num">{format_usd(ip.coverage_amount || Decimal.new(0))}</td>
                  <td class="num">{format_usd(ip.premium || Decimal.new(0))}</td>
                  <td>{ip.currency}</td>
                  <td>{ip.start_date || "-"}</td>
                  <td>{ip.expiry_date || "-"}</td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>

        <div class="footer-note">
          This report was generated automatically by Holdco. Review all compliance items for accuracy.
        </div>
      </body>
    </html>
    """
  end

  # Helper functions

  defp format_usd(nil), do: "$0.00"

  defp format_usd(%Decimal{} = amount) do
    float_amount = Decimal.to_float(amount)
    format_usd(float_amount)
  end

  defp format_usd(amount) when is_number(amount) do
    sign = if amount < 0, do: "-", else: ""
    abs_amount = abs(amount)
    integer_part = trunc(abs_amount)
    decimal_part = abs_amount - integer_part

    formatted_decimal =
      :erlang.float_to_binary(decimal_part, decimals: 2) |> String.slice(1..-1//1)

    formatted_integer = Integer.to_string(integer_part) |> add_commas()
    "#{sign}$#{formatted_integer}#{formatted_decimal}"
  end

  defp format_usd(_), do: "$0.00"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_pct(_value, total) when total == 0 or total == 0.0, do: "0.0%"
  defp format_pct(value, %Decimal{} = total) do
    if Decimal.equal?(total, 0), do: "0.0%", else: format_pct_calc(value, total)
  end
  defp format_pct(value, total), do: format_pct_calc(value, total)

  defp format_pct_calc(value, total) do
    v = if is_struct(value, Decimal), do: Decimal.to_float(value), else: value
    t = if is_struct(total, Decimal), do: Decimal.to_float(total), else: total
    pct = v / t * 100.0
    :erlang.float_to_binary(pct, decimals: 1) <> "%"
  end

  defp gain_class(%Decimal{} = value) do
    if Decimal.compare(value, 0) in [:gt, :eq], do: "positive", else: "negative"
  end
  defp gain_class(value) when is_number(value) and value >= 0, do: "positive"
  defp gain_class(value) when is_number(value) and value < 0, do: "negative"
  defp gain_class(_), do: ""

  defp status_tag("active"), do: "tag-active"
  defp status_tag("paid"), do: "tag-completed"
  defp status_tag("completed"), do: "tag-completed"
  defp status_tag(_), do: "tag-default"

  defp compliance_status_tag("pending"), do: "tag-pending"
  defp compliance_status_tag("filed"), do: "tag-filed"
  defp compliance_status_tag("completed"), do: "tag-completed"
  defp compliance_status_tag("active"), do: "tag-active"
  defp compliance_status_tag("overdue"), do: "tag-overdue"
  defp compliance_status_tag(_), do: "tag-default"

  defp pending_count(items) do
    Enum.count(items, fn item -> item.status == "pending" end)
  end
end
