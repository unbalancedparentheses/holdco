defmodule HoldcoWeb.DashboardLive do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Banking, Assets, Platform, Portfolio, Compliance, AI, Finance, Integrations}
  alias Holdco.Money

  @currencies ~w(USD EUR GBP ARS BRL CHF JPY CAD AUD)

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Platform.subscribe("audit")
      Platform.subscribe("portfolio")
    end

    nav = Portfolio.calculate_nav()
    companies = Corporate.list_companies() |> build_company_tree()
    recent_transactions = Banking.list_transactions(%{limit: 10})
    recent_audit = Platform.list_audit_logs(%{limit: 20})
    snapshots = Assets.list_portfolio_snapshots()
    allocation = Portfolio.asset_allocation()
    pending_approvals = Platform.pending_approval_count()

    upcoming_deadlines =
      Compliance.list_tax_deadlines()
      |> Enum.filter(fn td ->
        td.status in ["pending", "overdue"] and td.due_date != nil
      end)
      |> Enum.sort_by(& &1.due_date)
      |> Enum.take(5)

    # Action items
    unreconciled_count = Integrations.count_unmatched_bank_feed_transactions()
    due_recurring_count = length(Finance.list_due_recurring_transactions())

    today = Date.utc_today()
    first_of_month = Date.beginning_of_month(today)
    prev_month_end = Date.add(first_of_month, -1)
    prev_month_start = Date.beginning_of_month(prev_month_end)
    company_count = length(companies)

    locked_count =
      if company_count > 0 do
        companies
        |> Enum.count(fn c ->
          Finance.is_period_locked?(c.id, prev_month_start)
        end)
      else
        0
      end

    open_periods = company_count - locked_count

    ai_configured = AI.configured?()

    if connected?(socket) and ai_configured do
      send(self(), :load_ai_insight)
    end

    # New analytics
    returns = Portfolio.return_metrics()
    period_comp = Portfolio.period_comparison()
    ratios = Portfolio.financial_ratios()
    cash_forecast = Portfolio.cash_flow_forecast(90)
    entities = Portfolio.entity_performance()

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       nav: nav,
       companies: companies,
       recent_transactions: recent_transactions,
       recent_audit: recent_audit,
       snapshots: snapshots,
       allocation: allocation,
       display_currency: "USD",
       fx_rate: Decimal.new(1),
       pending_approvals: pending_approvals,
       upcoming_deadlines: upcoming_deadlines,
       ai_insight: nil,
       ai_insight_loading: ai_configured,
       returns: returns,
       period_comp: period_comp,
       ratios: ratios,
       cash_forecast: cash_forecast,
       entities: entities,
       unreconciled_count: unreconciled_count,
       due_recurring_count: due_recurring_count,
       open_periods: open_periods
     )}
  end

  @impl true
  def handle_event("change_currency", %{"currency" => currency}, socket) do
    fx_rate =
      if currency == "USD" do
        Decimal.new(1)
      else
        case Portfolio.get_fx_rate(currency) do
          rate when rate > 0 -> Money.div(1, rate)
          _ -> Decimal.new(1)
        end
      end

    {:noreply, assign(socket, display_currency: currency, fx_rate: fx_rate)}
  end

  @impl true
  def handle_info({:audit_log_created, log}, socket) do
    recent = [log | Enum.take(socket.assigns.recent_audit, 19)]
    {:noreply, assign(socket, recent_audit: recent)}
  end

  def handle_info(:load_ai_insight, socket) do
    data_context = AI.DataContext.build_summary()

    case AI.generate_insights(data_context) do
      {:ok, insight} ->
        {:noreply, assign(socket, ai_insight: insight, ai_insight_loading: false)}

      {:error, _} ->
        {:noreply, assign(socket, ai_insight: nil, ai_insight_loading: false)}
    end
  end

  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Portfolio Overview</h1>
          <p class="deck">Net Asset Value and holdings summary across all entities</p>
        </div>
        <form phx-change="change_currency" style="display: flex; align-items: center; gap: 0.5rem;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">Display Currency</label>
          <select name="currency" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <%= for ccy <- currencies() do %>
              <option value={ccy} selected={ccy == @display_currency}>{ccy}</option>
            <% end %>
          </select>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <%= if @can_write do %>
      <div style="display: flex; gap: 0.5rem; margin-bottom: 1.5rem; flex-wrap: wrap;">
        <.link navigate={~p"/companies/new"} class="btn btn-primary">+ Company</.link>
        <.link navigate={~p"/transactions"} class="btn btn-secondary">+ Transaction</.link>
        <.link navigate={~p"/holdings"} class="btn btn-secondary">+ Position</.link>
        <.link navigate={~p"/import"} class="btn btn-secondary">Import CSV</.link>
      </div>
    <% end %>

    <%!-- === Action Items === --%>
    <%= if @unreconciled_count > 0 or @open_periods > 0 or @due_recurring_count > 0 or @pending_approvals > 0 do %>
      <div style="display: flex; gap: 0.75rem; margin-bottom: 1.5rem; flex-wrap: wrap;">
        <%= if @unreconciled_count > 0 do %>
          <.link navigate={~p"/bank-reconciliation"} class="panel" style="padding: 0.75rem 1rem; text-decoration: none; color: inherit; border-left: 3px solid var(--color-crimson, #c0392b); flex: 1; min-width: 200px;">
            <div style="font-size: 1.25rem; font-weight: 700; color: var(--color-crimson, #c0392b);">{@unreconciled_count}</div>
            <div style="font-size: 0.8rem; color: var(--ink-faint);">Unreconciled transactions</div>
          </.link>
        <% end %>
        <%= if @open_periods > 0 do %>
          <.link navigate={~p"/period-close"} class="panel" style="padding: 0.75rem 1rem; text-decoration: none; color: inherit; border-left: 3px solid var(--color-lemon, #b8860b); flex: 1; min-width: 200px;">
            <div style="font-size: 1.25rem; font-weight: 700; color: var(--color-lemon, #b8860b);">{@open_periods}</div>
            <div style="font-size: 0.8rem; color: var(--ink-faint);">Periods open (prev month)</div>
          </.link>
        <% end %>
        <%= if @due_recurring_count > 0 do %>
          <.link navigate={~p"/recurring-transactions"} class="panel" style="padding: 0.75rem 1rem; text-decoration: none; color: inherit; border-left: 3px solid var(--color-lemon, #b8860b); flex: 1; min-width: 200px;">
            <div style="font-size: 1.25rem; font-weight: 700; color: var(--color-lemon, #b8860b);">{@due_recurring_count}</div>
            <div style="font-size: 0.8rem; color: var(--ink-faint);">Recurring entries due</div>
          </.link>
        <% end %>
        <%= if @pending_approvals > 0 do %>
          <.link navigate={~p"/approvals"} class="panel" style="padding: 0.75rem 1rem; text-decoration: none; color: inherit; border-left: 3px solid var(--color-crimson, #c0392b); flex: 1; min-width: 200px;">
            <div style="font-size: 1.25rem; font-weight: 700; color: var(--color-crimson, #c0392b);">{@pending_approvals}</div>
            <div style="font-size: 0.8rem; color: var(--ink-faint);">Pending approvals</div>
          </.link>
        <% end %>
      </div>
    <% end %>

    <%!-- === NAV Metrics Strip === --%>
    <% sym = currency_symbol(@display_currency) %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Net Asset Value</div>
        <div class="metric-value">{sym}{format_number(Money.mult(@nav.nav, @fx_rate))}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liquid</div>
        <div class="metric-value">{sym}{format_number(Money.mult(@nav.liquid, @fx_rate))}</div>
        <div class="metric-note">Bank balances</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Marketable</div>
        <div class="metric-value">{sym}{format_number(Money.mult(@nav.marketable, @fx_rate))}</div>
        <div class="metric-note">Stocks, crypto, commodities</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Illiquid</div>
        <div class="metric-value">{sym}{format_number(Money.mult(@nav.illiquid, @fx_rate))}</div>
        <div class="metric-note">Real estate, PE, funds</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liabilities</div>
        <div class="metric-value num-negative">{sym}{format_number(Money.mult(@nav.liabilities, @fx_rate))}</div>
      </div>
    </div>

    <%!-- === Returns & Period Comparison === --%>
    <div class="metrics-strip" id="returns-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Return</div>
        <div class={"metric-value #{gain_class(@returns.total_gain)}"}>
          {format_pct(@returns.total_return_pct)}
        </div>
        <div class="metric-note">
          {sym}{format_number(Money.mult(@returns.total_gain, @fx_rate))} gain
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Unrealized</div>
        <div class={"metric-value #{gain_class(@returns.unrealized_gain)}"}>
          {sym}{format_signed(Money.mult(@returns.unrealized_gain, @fx_rate))}
        </div>
        <div class="metric-note">{format_pct(@returns.unrealized_return_pct)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Realized</div>
        <div class={"metric-value #{gain_class(@returns.realized_gain)}"}>
          {sym}{format_signed(Money.mult(@returns.realized_gain, @fx_rate))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Cost Basis</div>
        <div class="metric-value">
          {sym}{format_number(Money.mult(@returns.total_cost_basis, @fx_rate))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">NAV Change</div>
        <div style="display: flex; gap: 0.75rem; flex-wrap: wrap; margin-top: 0.25rem;">
          <%= for p <- @period_comp do %>
            <%= if p.change_pct do %>
              <span style="display: inline-flex; flex-direction: column; align-items: center;">
                <span style="font-size: 0.7rem; color: var(--ink-faint); text-transform: uppercase; letter-spacing: 0.05em;">{p.label}</span>
                <span class={"tag #{period_tag(p.change_pct)}"} style="margin-top: 2px;">
                  {format_pct(p.change_pct)}
                </span>
              </span>
            <% end %>
          <% end %>
        </div>
      </div>
    </div>

    <%!-- === Asset Allocation & NAV History === --%>
    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Asset Allocation</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <% alloc_colors = ["#4a8c87", "#6b87a0", "#5f8f6e", "#8a5a6a", "#c08060", "#b89040", "#b0605e"] %>
          <% alloc_total = Enum.reduce(@allocation, Decimal.new(0), fn a, acc -> Money.add(acc, Money.max(a.value, a.count)) end) %>
          <div class="stacked-bar">
            <%= for {a, color} <- Enum.zip(@allocation, alloc_colors) do %>
              <% val = if Money.gt?(a.value, 0), do: a.value, else: a.count %>
              <% pct = if Money.gt?(alloc_total, 0), do: Money.to_float(Money.round(Money.mult(Money.div(val, alloc_total), 100), 1)), else: 0 %>
              <div class="stacked-bar-segment" style={"width: #{pct}%; background: #{color};"} title={"#{a.type}: #{pct}%"}>
                <%= if pct > 12 do %>
                  <span class="stacked-bar-label">{a.type}</span>
                <% end %>
              </div>
            <% end %>
          </div>
          <div class="stacked-bar-legend">
            <%= for {a, color} <- Enum.zip(@allocation, alloc_colors) do %>
              <% val = if Money.gt?(a.value, 0), do: a.value, else: a.count %>
              <% pct = if Money.gt?(alloc_total, 0), do: Money.to_float(Money.round(Money.mult(Money.div(val, alloc_total), 100), 1)), else: 0 %>
              <span class="stacked-bar-legend-item">
                <span class="stacked-bar-swatch" style={"background: #{color};"}></span>
                {a.type} <span class="stacked-bar-pct">{pct}%</span>
              </span>
            <% end %>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>NAV History</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="nav-chart"
            phx-hook="ChartHook"
            data-chart-type="line"
            data-chart-data={Jason.encode!(nav_chart_data(@snapshots))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{display: false}},
                scales: %{y: %{beginAtZero: false}}
              })
            }
            style="height: 250px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>
    </div>

    <%!-- === Financial Ratios & Cash Flow Forecast === --%>
    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Financial Ratios</h2>
        </div>
        <div class="panel" style="padding: 1.25rem;">
          <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 1.25rem;">
            <div>
              <div class="metric-label">Debt-to-Equity</div>
              <div class="metric-value" style="font-size: 1.5rem;">
                {format_ratio(@ratios.debt_to_equity)}
              </div>
              <div class="metric-note">
                <%= cond do %>
                  <% @ratios.debt_to_equity == nil -> %>
                    No equity data
                  <% @ratios.debt_to_equity < 0.5 -> %>
                    Conservative leverage
                  <% @ratios.debt_to_equity < 1.0 -> %>
                    Moderate leverage
                  <% true -> %>
                    High leverage
                <% end %>
              </div>
            </div>
            <div>
              <div class="metric-label">Current Ratio</div>
              <div class="metric-value" style="font-size: 1.5rem;">
                {format_ratio(@ratios.current_ratio)}
              </div>
              <div class="metric-note">
                <%= cond do %>
                  <% @ratios.current_ratio == nil -> %>
                    No short-term debt
                  <% @ratios.current_ratio > 2.0 -> %>
                    Strong liquidity
                  <% @ratios.current_ratio > 1.0 -> %>
                    Adequate liquidity
                  <% true -> %>
                    Liquidity concern
                <% end %>
              </div>
            </div>
            <div>
              <div class="metric-label">Liquidity Ratio</div>
              <div class="metric-value" style="font-size: 1.5rem;">
                {format_pct(@ratios.liquid_to_total_pct)}
              </div>
              <div class="metric-note">Cash / total assets</div>
            </div>
            <div>
              <div class="metric-label">Avg Interest Rate</div>
              <div class="metric-value" style="font-size: 1.5rem;">
                <%= if @ratios.weighted_avg_interest_rate do %>
                  {format_pct(@ratios.weighted_avg_interest_rate)}
                <% else %>
                  --
                <% end %>
              </div>
              <div class="metric-note">Weighted by principal</div>
            </div>
          </div>
          <div style="margin-top: 1.25rem; padding-top: 1rem; border-top: 1px solid var(--rule); display: flex; justify-content: space-between; font-size: 0.85rem;">
            <span>Total Assets: <strong>{sym}{format_number(Money.mult(@ratios.total_assets, @fx_rate))}</strong></span>
            <span>Equity: <strong>{sym}{format_number(Money.mult(@ratios.equity, @fx_rate))}</strong></span>
            <span>Debt: <strong>{sym}{format_number(Money.mult(@ratios.total_liabilities, @fx_rate))}</strong></span>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>90-Day Cash Forecast</h2>
          <span class="count">90 days</span>
        </div>
        <div class="panel" style="padding: 1.25rem;">
          <div style="display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 1rem; margin-bottom: 1rem;">
            <div>
              <div class="metric-label">Starting Cash</div>
              <div style="font-family: var(--font-display); font-size: 1.1rem; font-weight: 600;">
                {sym}{format_number(Money.mult(@cash_forecast.starting_balance, @fx_rate))}
              </div>
            </div>
            <div>
              <div class="metric-label">Net Flow</div>
              <div style={"font-family: var(--font-display); font-size: 1.1rem; font-weight: 600; color: #{if Money.negative?(@cash_forecast.net_flow), do: "var(--crimson)", else: "var(--jade)"};"}>
                {sym}{format_signed(Money.mult(@cash_forecast.net_flow, @fx_rate))}
              </div>
            </div>
            <div>
              <div class="metric-label">Ending Cash</div>
              <div style="font-family: var(--font-display); font-size: 1.1rem; font-weight: 600;">
                {sym}{format_number(Money.mult(@cash_forecast.ending_balance, @fx_rate))}
              </div>
            </div>
          </div>
          <div style="display: flex; gap: 1.5rem; font-size: 0.85rem; padding-top: 0.75rem; border-top: 1px solid var(--rule);">
            <span>Inflows: <strong class="num-positive">{sym}{format_number(Money.mult(@cash_forecast.total_inflows, @fx_rate))}</strong></span>
            <span>Outflows: <strong class="num-negative">{sym}{format_number(Money.mult(@cash_forecast.total_outflows, @fx_rate))}</strong></span>
            <span>{length(@cash_forecast.flows)} scheduled items</span>
          </div>
          <%= if @cash_forecast.flows != [] do %>
            <div
              id="cashflow-chart"
              phx-hook="ChartHook"
              data-chart-type="line"
              data-chart-data={Jason.encode!(cashflow_chart_data(@cash_forecast))}
              data-chart-options={Jason.encode!(%{
                plugins: %{legend: %{display: false}},
                scales: %{y: %{beginAtZero: false}}
              })}
              style="height: 150px; margin-top: 1rem;"
            >
              <canvas></canvas>
            </div>
          <% else %>
            <div class="empty-state" style="margin-top: 1rem;">
              No scheduled cash flows in the next 90 days
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <%!-- === Entity Performance === --%>
    <%= if length(@entities) > 1 do %>
      <div class="section">
        <div class="section-head">
          <h2>Entity Performance</h2>
          <span class="count">{length(@entities)} entities</span>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Entity</th>
                <th>Category</th>
                <th class="th-num">Cash</th>
                <th class="th-num">Holdings</th>
                <th class="th-num">Liabilities</th>
                <th class="th-num">NAV</th>
                <th class="th-num">Return</th>
              </tr>
            </thead>
            <tbody>
              <%= for entity <- @entities do %>
                <tr>
                  <td>
                    <.link navigate={~p"/companies/#{entity.id}"} class="td-link td-name">{entity.name}</.link>
                  </td>
                  <td><span class="tag tag-ink">{entity.category}</span></td>
                  <td class="td-num">{sym}{format_number(Money.mult(entity.liquid, @fx_rate))}</td>
                  <td class="td-num">{sym}{format_number(Money.mult(entity.holdings_value, @fx_rate))}</td>
                  <td class="td-num num-negative">
                    <%= if Money.gt?(entity.liabilities, 0) do %>
                      {sym}{format_number(Money.mult(entity.liabilities, @fx_rate))}
                    <% else %>
                      --
                    <% end %>
                  </td>
                  <td class="td-num" style="font-weight: 600;">
                    {sym}{format_number(Money.mult(entity.nav, @fx_rate))}
                  </td>
                  <td class={"td-num #{if entity.return_pct && entity.return_pct >= 0, do: "num-positive", else: "num-negative"}"}>
                    <%= if entity.return_pct do %>
                      {format_pct(entity.return_pct)}
                    <% else %>
                      --
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    <% end %>

    <%!-- === Corporate Structure & Recent Activity === --%>
    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Corporate Structure</h2>
          <.link navigate={~p"/companies"} class="count" style="text-decoration: none;">{length(@companies)} entities &rarr;</.link>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Entity</th>
                <th>Country</th>
                <th>Category</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for company <- @companies do %>
                <tr>
                  <td class={if company.parent_id, do: "indent"}>
                    <%= if company.parent_id do %><span style="color: var(--color-muted); margin-right: 0.25rem;">&mdash;</span><% end %><.link navigate={~p"/companies/#{company.id}"} class="td-link td-name">
                      {company.name}
                    </.link>
                  </td>
                  <td>{company.country}</td>
                  <td>{company.category}</td>
                  <td>
                    <span class={"tag #{status_tag(company.wind_down_status)}"}>
                      {company.wind_down_status}
                    </span>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Recent Activity</h2>
          <.link navigate={~p"/audit-log"} class="count" style="text-decoration: none;">View All &rarr;</.link>
        </div>
        <div class="panel" id="audit-feed">
          <table>
            <thead>
              <tr>
                <th>Time</th>
                <th>Action</th>
                <th>Table</th>
                <th>Record</th>
              </tr>
            </thead>
            <tbody>
              <%= for log <- @recent_audit do %>
                <tr>
                  <td class="td-mono">{format_time(log.inserted_at)}</td>
                  <td><span class={"tag #{action_tag(log.action)}"}>{log.action}</span></td>
                  <td>{log.table_name}</td>
                  <td class="td-mono">
                    <.link navigate={audit_link(log.table_name, log.record_id)} class="td-link">
                      #{log.record_id}
                    </.link>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <%!-- === Deadlines & Approvals === --%>
    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Upcoming Deadlines</h2>
          <.link navigate={~p"/calendar"} class="count" style="text-decoration: none;">View All &rarr;</.link>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Due Date</th>
                <th>Description</th>
                <th>Company</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              <%= for td <- @upcoming_deadlines do %>
                <tr>
                  <td class="td-mono">{td.due_date}</td>
                  <td class="td-name">{td.description}</td>
                  <td>
                    <%= if td.company do %>
                      <.link navigate={~p"/companies/#{td.company.id}"} class="td-link">{td.company.name}</.link>
                    <% else %>
                      ---
                    <% end %>
                  </td>
                  <td><span class={"tag #{deadline_tag(td.status)}"}>{td.status}</span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @upcoming_deadlines == [] do %>
            <div class="empty-state">No upcoming deadlines. You're all clear!</div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Pending Approvals</h2>
          <.link navigate={~p"/approvals"} class="count" style="text-decoration: none;">View All &rarr;</.link>
        </div>
        <div class="panel" style="padding: 1.5rem; text-align: center;">
          <div class="metric-value" style="font-size: 2.5rem;">{@pending_approvals}</div>
          <div class="metric-label" style="margin-top: 0.5rem;">
            <%= if @pending_approvals == 0 do %>
              No pending approvals
            <% else %>
              <.link navigate={~p"/approvals"} class="td-link">Review pending approvals</.link>
            <% end %>
          </div>
        </div>
      </div>
    </div>

    <%!-- === Tools Grid === --%>
    <div class="section">
      <div class="section-head">
        <h2>Tools & Analysis</h2>
      </div>
      <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr)); gap: 0.75rem;">
        <.link navigate={~p"/bank-accounts"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Bank Accounts</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Cash positions</div>
        </.link>
        <.link navigate={~p"/financials"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Financials</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Revenue & expenses</div>
        </.link>
        <.link navigate={~p"/documents"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Documents</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Files & records</div>
        </.link>
        <.link navigate={~p"/contacts"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Contacts</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">People & orgs</div>
        </.link>
        <.link navigate={~p"/contracts"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Contracts</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Agreements & terms</div>
        </.link>
        <.link navigate={~p"/alerts"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Alerts</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Rules & triggers</div>
        </.link>
        <.link navigate={~p"/anomalies"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Anomalies</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Fraud detection</div>
        </.link>
        <.link navigate={~p"/consolidated"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Consolidated</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Group financials</div>
        </.link>
        <.link navigate={~p"/bank-reconciliation"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Reconciliation</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Match bank feeds</div>
        </.link>
      </div>
    </div>

    <%!-- === AI Insights === --%>
    <%= if @ai_insight_loading or @ai_insight do %>
      <div class="section">
        <div class="section-head">
          <h2>AI Insights</h2>
          <span class="count" style="color: var(--color-muted); font-size: 0.85rem;">Use chat button &rarr;</span>
        </div>
        <div class="panel" style="padding: 1.25rem;">
          <%= if @ai_insight_loading do %>
            <div style="color: #999; font-style: italic;">Generating insights...</div>
          <% else %>
            <div style="white-space: pre-wrap; font-size: 0.9rem; line-height: 1.5;">{@ai_insight}</div>
          <% end %>
        </div>
      </div>
    <% end %>

    <%!-- === Recent Transactions === --%>
    <div class="section">
      <div class="section-head">
        <h2>Recent Transactions</h2>
        <.link navigate={~p"/transactions"} class="count" style="text-decoration: none;">{length(@recent_transactions)} latest &rarr;</.link>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Type</th>
              <th>Description</th>
              <th>Counterparty</th>
              <th class="th-num">Amount</th>
            </tr>
          </thead>
          <tbody>
            <%= for tx <- @recent_transactions do %>
              <tr>
                <td class="td-mono">{tx.date}</td>
                <td><span class="tag tag-ink">{tx.transaction_type}</span></td>
                <td class="td-name">{tx.description}</td>
                <td>{tx.counterparty}</td>
                <td class={"td-num #{if tx.amount && Money.negative?(tx.amount), do: "num-negative", else: "num-positive"}"}>
                  {format_currency(tx.amount, tx.currency)}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  # --- Helpers ---

  defp currencies, do: @currencies

  defp currency_symbol("USD"), do: "$"
  defp currency_symbol("EUR"), do: "€"
  defp currency_symbol("GBP"), do: "£"
  defp currency_symbol("JPY"), do: "¥"
  defp currency_symbol("CHF"), do: "CHF "
  defp currency_symbol(ccy), do: "#{ccy} "

  defp format_number(%Decimal{} = n),
    do: :erlang.float_to_binary(Money.to_float(n), decimals: 0) |> add_commas()

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_currency(nil, _currency), do: "0"

  defp format_currency(amount, currency) do
    sign = if Money.negative?(amount), do: "-", else: ""
    "#{sign}#{format_number(Money.abs(amount))} #{currency}"
  end

  defp format_signed(%Decimal{} = n) do
    if Money.negative?(n) do
      "-#{format_number(Money.abs(n))}"
    else
      "+#{format_number(n)}"
    end
  end

  defp format_signed(_), do: "0"

  defp format_pct(nil), do: "--"

  defp format_pct(n) when is_float(n) do
    sign = if n >= 0, do: "+", else: ""
    "#{sign}#{:erlang.float_to_binary(n, decimals: 1)}%"
  end

  defp format_pct(n) when is_integer(n), do: format_pct(n * 1.0)
  defp format_pct(_), do: "--"

  defp format_ratio(nil), do: "--"
  defp format_ratio(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2)
  defp format_ratio(_), do: "--"

  defp gain_class(%Decimal{} = n) do
    cond do
      Money.positive?(n) -> "num-positive"
      Money.negative?(n) -> "num-negative"
      true -> ""
    end
  end

  defp gain_class(_), do: ""

  defp period_tag(pct) when is_float(pct) and pct >= 0, do: "tag-jade"
  defp period_tag(pct) when is_float(pct), do: "tag-crimson"
  defp period_tag(_), do: "tag-ink"

  defp format_time(nil), do: ""
  defp format_time(dt), do: Calendar.strftime(dt, "%H:%M:%S")

  defp status_tag("active"), do: "tag-jade"
  defp status_tag("winding_down"), do: "tag-lemon"
  defp status_tag("dissolved"), do: "tag-crimson"
  defp status_tag(_), do: "tag-ink"

  defp action_tag("create"), do: "tag-jade"
  defp action_tag("update"), do: "tag-lemon"
  defp action_tag("delete"), do: "tag-crimson"
  defp action_tag(_), do: "tag-ink"

  defp deadline_tag("overdue"), do: "tag-crimson"
  defp deadline_tag("pending"), do: "tag-lemon"
  defp deadline_tag("completed"), do: "tag-jade"
  defp deadline_tag(_), do: "tag-ink"

  defp audit_link(_, nil), do: "#"
  defp audit_link("companies", id), do: ~p"/companies/#{id}"
  defp audit_link("asset_holdings", id), do: ~p"/holdings/#{id}"
  defp audit_link("bank_accounts", id), do: ~p"/bank-accounts/#{id}"
  defp audit_link("transactions", id), do: ~p"/transactions/#{id}"
  defp audit_link(_, id), do: ~p"/audit-log?table_name=&record=#{id}"

  defp build_company_tree(companies) do
    {roots, children} = Enum.split_with(companies, &is_nil(&1.parent_id))
    by_parent = Enum.group_by(children, & &1.parent_id)

    Enum.flat_map(roots, fn root ->
      [root | Map.get(by_parent, root.id, [])]
    end)
  end

  defp nav_chart_data(snapshots) do
    sorted = Enum.sort_by(snapshots, & &1.date)

    %{
      labels: Enum.map(sorted, & &1.date),
      datasets: [
        %{
          label: "NAV",
          data: Enum.map(sorted, &Money.to_float(&1.nav)),
          borderColor: "#4a8c87",
          backgroundColor: "rgba(74, 140, 135, 0.1)",
          fill: true,
          tension: 0.3
        }
      ]
    }
  end

  defp cashflow_chart_data(forecast) do
    flows = forecast.flows
    starting = Money.to_float(forecast.starting_balance)

    # Build data points: start with starting balance, then running balances
    dates = ["Today" | Enum.map(flows, & &1.date)]
    balances = [starting | Enum.map(flows, &Money.to_float(&1.running_balance))]

    %{
      labels: dates,
      datasets: [
        %{
          label: "Cash Balance",
          data: balances,
          borderColor: "#4a8c87",
          backgroundColor: "rgba(74, 140, 135, 0.1)",
          fill: true,
          tension: 0.3,
          pointRadius: 2
        }
      ]
    }
  end
end
