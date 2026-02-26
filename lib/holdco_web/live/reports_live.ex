defmodule HoldcoWeb.ReportsLive do
  use HoldcoWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Reports")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Reports</h1>
      <p class="deck">Generate printable reports for portfolio, financial, and compliance data</p>
      <hr class="page-title-rule" />
    </div>

    <div
      class="grid-3"
      style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem;"
    >
      <div class="panel" style="padding: 1.5rem;">
        <h2 style="font-family: 'Source Serif 4', Georgia, serif; font-size: 1.1rem; margin-bottom: 0.5rem;">
          Portfolio NAV Report
        </h2>
        <p style="color: #666; font-size: 0.85rem; margin-bottom: 1rem; line-height: 1.5;">
          Complete portfolio overview including NAV breakdown, asset allocation by type,
          FX currency exposure, and unrealized/realized gains summary for all holdings.
        </p>
        <div style="font-size: 0.8rem; color: #888; margin-bottom: 1rem;">
          <div style="margin-bottom: 0.25rem;">Includes:</div>
          <ul style="margin-left: 1.25rem; line-height: 1.6;">
            <li>NAV breakdown (liquid, marketable, illiquid, liabilities)</li>
            <li>Asset allocation table with percentages</li>
            <li>FX exposure by currency</li>
            <li>Per-holding gains detail</li>
          </ul>
        </div>
        <a
          href={~p"/reports/portfolio"}
          target="_blank"
          style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
        >
          Generate Report
        </a>
      </div>

      <div class="panel" style="padding: 1.5rem;">
        <h2 style="font-family: 'Source Serif 4', Georgia, serif; font-size: 1.1rem; margin-bottom: 0.5rem;">
          Financial Summary Report
        </h2>
        <p style="color: #666; font-size: 0.85rem; margin-bottom: 1rem; line-height: 1.5;">
          Consolidated financial summary with P&L breakdown by company entity,
          revenue and expense totals, net income, and outstanding liabilities detail.
        </p>
        <div style="font-size: 0.8rem; color: #888; margin-bottom: 1rem;">
          <div style="margin-bottom: 0.25rem;">Includes:</div>
          <ul style="margin-left: 1.25rem; line-height: 1.6;">
            <li>Consolidated revenue, expenses, net income</li>
            <li>P&L by company with period detail</li>
            <li>Liabilities schedule with interest rates</li>
            <li>Total liabilities outstanding</li>
          </ul>
        </div>
        <a
          href={~p"/reports/financial"}
          target="_blank"
          style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
        >
          Generate Report
        </a>
      </div>

      <div class="panel" style="padding: 1.5rem;">
        <h2 style="font-family: 'Source Serif 4', Georgia, serif; font-size: 1.1rem; margin-bottom: 0.5rem;">
          Compliance Status Report
        </h2>
        <p style="color: #666; font-size: 0.85rem; margin-bottom: 1rem; line-height: 1.5;">
          Full compliance overview including upcoming tax deadlines, regulatory filing
          statuses, and active insurance policies across all entities.
        </p>
        <div style="font-size: 0.8rem; color: #888; margin-bottom: 1rem;">
          <div style="margin-bottom: 0.25rem;">Includes:</div>
          <ul style="margin-left: 1.25rem; line-height: 1.6;">
            <li>Tax deadlines by company and jurisdiction</li>
            <li>Regulatory filing status and references</li>
            <li>Insurance policy coverage and expiry dates</li>
            <li>Pending item counts</li>
          </ul>
        </div>
        <a
          href={~p"/reports/compliance"}
          target="_blank"
          style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
        >
          Generate Report
        </a>
      </div>
    </div>

    <div class="section" style="margin-top: 2rem;">
      <div class="panel" style="padding: 1.25rem;">
        <p style="color: #888; font-size: 0.85rem; line-height: 1.6;">
          Reports open in a new tab as printable HTML pages. Use your browser's <strong>Print</strong>
          function (Ctrl+P / Cmd+P) or the "Print / Save as PDF"
          button on the report page to save as a PDF document. All data is fetched
          live at the time of generation.
        </p>
      </div>
    </div>
    """
  end
end
