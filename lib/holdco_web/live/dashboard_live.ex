defmodule HoldcoWeb.DashboardLive do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Banking, Assets, Platform, Portfolio, Compliance, AI}
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

    ai_configured = AI.configured?()

    if connected?(socket) and ai_configured do
      send(self(), :load_ai_insight)
    end

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
       ai_insight_loading: ai_configured
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
        <.link navigate={~p"/risk/concentration"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Concentration</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Risk exposure</div>
        </.link>
        <.link navigate={~p"/stress-test"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Stress Test</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">Monte Carlo shocks</div>
        </.link>
        <.link navigate={~p"/cash-forecast"} class="panel" style="padding: 1rem; text-decoration: none; color: inherit;">
          <div style="font-weight: 600; font-size: 0.85rem;">Cash Forecast</div>
          <div style="font-size: 0.75rem; color: var(--ink-faint); margin-top: 0.25rem;">12-month projection</div>
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
    # Put parent companies (no parent_id) first, then children grouped under their parent
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
end
