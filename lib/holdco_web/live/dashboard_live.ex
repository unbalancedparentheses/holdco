defmodule HoldcoWeb.DashboardLive do
  use HoldcoWeb, :live_view

  alias Holdco.{Corporate, Banking, Assets, Finance, Platform, Portfolio}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Platform.subscribe("audit")
      Platform.subscribe("portfolio")
    end

    nav = Portfolio.calculate_nav()
    companies = Corporate.list_companies()
    recent_transactions = Banking.list_transactions(%{limit: 10})
    recent_audit = Platform.list_audit_logs(%{limit: 20})
    snapshots = Assets.list_portfolio_snapshots()
    allocation = Portfolio.asset_allocation()

    {:ok, assign(socket,
      page_title: "Dashboard",
      nav: nav,
      companies: companies,
      recent_transactions: recent_transactions,
      recent_audit: recent_audit,
      snapshots: snapshots,
      allocation: allocation
    )}
  end

  @impl true
  def handle_info({:audit_log_created, log}, socket) do
    recent = [log | Enum.take(socket.assigns.recent_audit, 19)]
    {:noreply, assign(socket, recent_audit: recent)}
  end
  def handle_info(_, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Portfolio Overview</h1>
      <p class="deck">Net Asset Value and holdings summary across all entities</p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Net Asset Value</div>
        <div class="metric-value">$<%= format_number(@nav.nav) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liquid</div>
        <div class="metric-value">$<%= format_number(@nav.liquid) %></div>
        <div class="metric-note">Bank balances</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Marketable</div>
        <div class="metric-value">$<%= format_number(@nav.marketable) %></div>
        <div class="metric-note">Stocks, crypto, commodities</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Illiquid</div>
        <div class="metric-value">$<%= format_number(@nav.illiquid) %></div>
        <div class="metric-note">Real estate, PE, funds</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Liabilities</div>
        <div class="metric-value num-negative">$<%= format_number(@nav.liabilities) %></div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Asset Allocation</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="allocation-chart"
            phx-hook="ChartHook"
            data-chart-type="doughnut"
            data-chart-data={Jason.encode!(allocation_chart_data(@allocation))}
            data-chart-options={Jason.encode!(%{plugins: %{legend: %{position: "right"}}})}
            style="height: 250px;"
          >
            <canvas></canvas>
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
            data-chart-options={Jason.encode!(%{plugins: %{legend: %{display: false}}, scales: %{y: %{beginAtZero: false}}})}
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
          <span class="count"><%= length(@companies) %> entities</span>
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
                    <.link navigate={~p"/companies/#{company.id}"} class="td-link td-name">
                      <%= company.name %>
                    </.link>
                  </td>
                  <td><%= company.country %></td>
                  <td><%= company.category %></td>
                  <td><span class={"tag #{status_tag(company.wind_down_status)}"}><%= company.wind_down_status %></span></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Recent Activity</h2>
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
                  <td class="td-mono"><%= format_time(log.inserted_at) %></td>
                  <td><span class={"tag #{action_tag(log.action)}"}><%= log.action %></span></td>
                  <td><%= log.table_name %></td>
                  <td class="td-mono">#<%= log.record_id %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Recent Transactions</h2>
        <span class="count"><%= length(@recent_transactions) %> latest</span>
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
                <td class="td-mono"><%= tx.date %></td>
                <td><span class="tag tag-ink"><%= tx.transaction_type %></span></td>
                <td class="td-name"><%= tx.description %></td>
                <td><%= tx.counterparty %></td>
                <td class={"td-num #{if tx.amount && tx.amount < 0, do: "num-negative", else: "num-positive"}"}><%= format_currency(tx.amount, tx.currency) %></td>
              </tr>
            <% end %>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()
  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

  defp format_currency(nil, _currency), do: "0"
  defp format_currency(amount, currency) do
    sign = if amount < 0, do: "-", else: ""
    "#{sign}#{format_number(abs(amount))} #{currency}"
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

  defp allocation_chart_data(allocation) do
    colors = ["#0d7680", "#0f5499", "#00994d", "#990f3d", "#ff8833", "#f2a900", "#cc0000"]
    %{
      labels: Enum.map(allocation, & &1.type),
      datasets: [%{
        data: Enum.map(allocation, & &1.value),
        backgroundColor: Enum.take(colors, length(allocation))
      }]
    }
  end

  defp nav_chart_data(snapshots) do
    sorted = Enum.sort_by(snapshots, & &1.date)
    %{
      labels: Enum.map(sorted, & &1.date),
      datasets: [%{
        label: "NAV",
        data: Enum.map(sorted, & &1.nav),
        borderColor: "#0d7680",
        backgroundColor: "rgba(13, 118, 128, 0.1)",
        fill: true,
        tension: 0.3
      }]
    }
  end
end
