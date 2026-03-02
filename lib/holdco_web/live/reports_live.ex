defmodule HoldcoWeb.ReportsLive do
  use HoldcoWeb, :live_view

  alias Holdco.Analytics

  @impl true
  def mount(_params, _session, socket) do
    scheduled_reports =
      Analytics.list_scheduled_reports()
      |> Enum.filter(& &1.is_active)
      |> Enum.sort_by(& &1.next_run_date)
      |> Enum.take(5)

    {:ok, assign(socket, page_title: "Reports", scheduled_reports: scheduled_reports)}
  end

  @impl true
  def handle_event("print_page", _, socket) do
    {:noreply, push_event(socket, "js-print", %{})}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="reports-page" phx-hook="PrintHook">
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
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <a
              href={~p"/reports/portfolio"}
              target="_blank"
              style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
            >
              Generate Report
            </a>
            <button
              phx-click={JS.dispatch("js:print-report", to: "#reports-page", detail: %{url: ~p"/reports/portfolio"})}
              class="btn btn-secondary"
              style="font-size: 0.85rem; padding: 0.5rem 1rem;"
            >
              Save as PDF
            </button>
          </div>
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
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <a
              href={~p"/reports/financial"}
              target="_blank"
              style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
            >
              Generate Report
            </a>
            <button
              phx-click={JS.dispatch("js:print-report", to: "#reports-page", detail: %{url: ~p"/reports/financial"})}
              class="btn btn-secondary"
              style="font-size: 0.85rem; padding: 0.5rem 1rem;"
            >
              Save as PDF
            </button>
          </div>
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
          <div style="display: flex; gap: 0.5rem; align-items: center;">
            <a
              href={~p"/reports/compliance"}
              target="_blank"
              style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
            >
              Generate Report
            </a>
            <button
              phx-click={JS.dispatch("js:print-report", to: "#reports-page", detail: %{url: ~p"/reports/compliance"})}
              class="btn btn-secondary"
              style="font-size: 0.85rem; padding: 0.5rem 1rem;"
            >
              Save as PDF
            </button>
          </div>
        </div>
      </div>

      <div
        class="grid-3"
        style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 1.5rem; margin-top: 1.5rem;"
      >
        <div class="panel" style="padding: 1.5rem;">
          <h2 style="font-family: 'Source Serif 4', Georgia, serif; font-size: 1.1rem; margin-bottom: 0.5rem;">
            Audit Package
          </h2>
          <p style="color: #666; font-size: 0.85rem; margin-bottom: 1rem; line-height: 1.5;">
            Comprehensive audit package with trial balance, journal entries, supporting
            schedules, and document index for external auditor review.
          </p>
          <div style="font-size: 0.8rem; color: #888; margin-bottom: 1rem;">
            <div style="margin-bottom: 0.25rem;">Includes:</div>
            <ul style="margin-left: 1.25rem; line-height: 1.6;">
              <li>Trial balance and chart of accounts</li>
              <li>Journal entry detail with supporting docs</li>
              <li>Bank reconciliation summaries</li>
              <li>Compliance and governance checklists</li>
            </ul>
          </div>
          <a
            href={~p"/export/audit-package.zip"}
            style="display: inline-block; background: #0d7680; color: #fff; padding: 0.5rem 1.25rem; border-radius: 4px; text-decoration: none; font-size: 0.85rem; font-weight: 600;"
          >
            Download Package
          </a>
        </div>
      </div>

      <div class="section" style="margin-top: 2rem;">
        <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
          <h2 style="font-family: 'Source Serif 4', Georgia, serif; font-size: 1.1rem;">Scheduled Reports</h2>
          <.link navigate={~p"/scheduled-reports"} class="td-link" style="font-size: 0.85rem;">View All</.link>
        </div>
        <div class="panel">
          <%= if @scheduled_reports != [] do %>
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Frequency</th>
                  <th>Next Run</th>
                </tr>
              </thead>
              <tbody>
                <%= for r <- @scheduled_reports do %>
                  <tr>
                    <td class="td-name">{r.name}</td>
                    <td><span class="tag tag-ink">{r.report_type}</span></td>
                    <td>{r.frequency}</td>
                    <td class="td-mono">{r.next_run_date || "Not set"}</td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          <% else %>
            <div class="empty-state" style="padding: 1rem;">
              No active scheduled reports.
              <.link navigate={~p"/scheduled-reports"} class="td-link">Configure one</.link>
            </div>
          <% end %>
        </div>
      </div>

      <div class="section" style="margin-top: 2rem;">
        <div class="panel" style="padding: 1.25rem;">
          <p style="color: #888; font-size: 0.85rem; line-height: 1.6;">
            Reports open in a new tab as printable HTML pages. Use the <strong>"Save as PDF"</strong>
            button to open the report and trigger your browser's print dialog (Ctrl+P / Cmd+P),
            or click "Generate Report" to open in a new tab and print manually.
            All data is fetched live at the time of generation.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
