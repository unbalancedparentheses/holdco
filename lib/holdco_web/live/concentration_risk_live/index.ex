defmodule HoldcoWeb.ConcentrationRiskLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Portfolio, Assets}

  @concentration_threshold 25.0

  @impl true
  def mount(_params, _session, socket) do
    nav = Portfolio.calculate_nav()
    allocation = Portfolio.asset_allocation()
    fx_exposure = Portfolio.fx_exposure()
    holdings = Assets.list_holdings()

    holdings_with_values =
      holdings
      |> Enum.map(fn h ->
        value = Portfolio.holding_value(h)
        %{holding: h, value: value}
      end)
      |> Enum.sort_by(& &1.value, :desc)

    total_portfolio = nav.nav
    concentration_alerts = build_alerts(holdings_with_values, total_portfolio)

    {:ok,
     assign(socket,
       page_title: "Concentration Risk",
       nav: nav,
       allocation: allocation,
       fx_exposure: fx_exposure,
       holdings_with_values: holdings_with_values,
       total_portfolio: total_portfolio,
       concentration_alerts: concentration_alerts
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Concentration Risk</h1>
      <p class="deck">
        Portfolio concentration analysis across asset types, currencies, and individual positions
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total NAV</div>
        <div class="metric-value">${format_number(@nav.nav)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Asset Types</div>
        <div class="metric-value">{length(@allocation)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Currency Exposures</div>
        <div class="metric-value">{length(@fx_exposure)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Concentration Alerts</div>
        <div class={"metric-value #{if length(@concentration_alerts) > 0, do: "num-negative", else: "num-positive"}"}>
          {length(@concentration_alerts)}
        </div>
      </div>
    </div>

    <%= if @concentration_alerts != [] do %>
      <div class="section">
        <div class="section-head">
          <h2>Concentration Alerts</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <%= for alert <- @concentration_alerts do %>
            <div style="display: flex; align-items: center; gap: 0.75rem; padding: 0.5rem 0; border-bottom: 1px solid #f0f0f0;">
              <span class="tag tag-crimson">ALERT</span>
              <span>{alert.message}</span>
              <span class="td-num num-negative" style="margin-left: auto;">
                {Float.round(alert.pct, 1)}% of NAV
              </span>
            </div>
          <% end %>
        </div>
      </div>
    <% end %>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Allocation by Asset Type</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="allocation-pie-chart"
            phx-hook="ChartHook"
            data-chart-type="pie"
            data-chart-data={Jason.encode!(allocation_chart_data(@allocation))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{position: "right"}}
              })
            }
            style="height: 300px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>FX Currency Exposure</h2>
        </div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="fx-bar-chart"
            phx-hook="ChartHook"
            data-chart-type="bar"
            data-chart-data={Jason.encode!(fx_chart_data(@fx_exposure))}
            data-chart-options={
              Jason.encode!(%{
                plugins: %{legend: %{display: false}},
                scales: %{y: %{beginAtZero: true}}
              })
            }
            style="height: 300px;"
          >
            <canvas></canvas>
          </div>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Allocation Breakdown</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Asset Type</th>
                <th class="th-num">Value (USD)</th>
                <th class="th-num">Holdings</th>
                <th class="th-num">% of Portfolio</th>
              </tr>
            </thead>
            <tbody>
              <% alloc_total = Enum.reduce(@allocation, 0.0, fn a, acc -> acc + max(a.value, 0) end) %>
              <%= for a <- @allocation do %>
                <% pct = if alloc_total > 0, do: a.value / alloc_total * 100, else: 0.0 %>
                <tr>
                  <td class="td-name">{a.type || "Unknown"}</td>
                  <td class="td-num">${format_number(a.value)}</td>
                  <td class="td-num">{a.count}</td>
                  <td class={"td-num #{if pct > 25, do: "num-negative", else: ""}"}>
                    {Float.round(pct, 1)}%
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>FX Exposure Breakdown</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Currency</th>
                <th class="th-num">USD Value</th>
                <th class="th-num">% of Portfolio</th>
              </tr>
            </thead>
            <tbody>
              <% fx_total = Enum.reduce(@fx_exposure, 0.0, fn f, acc -> acc + max(f.usd_value, 0) end) %>
              <%= for f <- @fx_exposure do %>
                <% pct = if fx_total > 0, do: f.usd_value / fx_total * 100, else: 0.0 %>
                <tr>
                  <td class="td-name">{f.currency}</td>
                  <td class="td-num">${format_number(f.usd_value)}</td>
                  <td class={"td-num #{if pct > 50, do: "num-negative", else: ""}"}>
                    {Float.round(pct, 1)}%
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Top Holdings by Value</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Ticker</th>
              <th>Type</th>
              <th class="th-num">Value (USD)</th>
              <th class="th-num">% of NAV</th>
              <th>Risk</th>
            </tr>
          </thead>
          <tbody>
            <%= for hv <- Enum.take(@holdings_with_values, 20) do %>
              <% pct = if @total_portfolio > 0, do: hv.value / @total_portfolio * 100, else: 0.0 %>
              <tr>
                <td class="td-name">{hv.holding.asset}</td>
                <td class="td-mono">{hv.holding.ticker || "---"}</td>
                <td><span class="tag tag-ink">{hv.holding.asset_type}</span></td>
                <td class="td-num">${format_number(hv.value)}</td>
                <td class={"td-num #{if pct > concentration_threshold(), do: "num-negative", else: ""}"}>{Float.round(pct, 1)}%</td>
                <td>
                  <%= if pct > concentration_threshold() do %>
                    <span class="tag tag-crimson">HIGH</span>
                  <% else %>
                    <%= if pct > 15 do %>
                      <span class="tag tag-lemon">MEDIUM</span>
                    <% else %>
                      <span class="tag tag-jade">LOW</span>
                    <% end %>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @holdings_with_values == [] do %>
          <div class="empty-state">No holdings found. Add holdings to see concentration analysis.</div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp concentration_threshold, do: @concentration_threshold

  defp build_alerts(holdings_with_values, total_portfolio) when total_portfolio > 0 do
    holdings_with_values
    |> Enum.filter(fn hv ->
      pct = hv.value / total_portfolio * 100
      pct > @concentration_threshold
    end)
    |> Enum.map(fn hv ->
      pct = hv.value / total_portfolio * 100

      %{
        message:
          "#{hv.holding.asset} (#{hv.holding.ticker || "no ticker"}) exceeds #{@concentration_threshold}% threshold",
        pct: pct
      }
    end)
  end

  defp build_alerts(_, _), do: []

  defp allocation_chart_data(allocation) do
    colors = ["#4a8c87", "#6b87a0", "#5f8f6e", "#8a5a6a", "#c08060", "#b89040", "#b0605e", "#7a6b8a"]

    %{
      labels: Enum.map(allocation, fn a -> a.type || "Unknown" end),
      datasets: [
        %{
          data: Enum.map(allocation, & &1.value),
          backgroundColor: Enum.take(Stream.cycle(colors), length(allocation))
        }
      ]
    }
  end

  defp fx_chart_data(fx_exposure) do
    %{
      labels: Enum.map(fx_exposure, & &1.currency),
      datasets: [
        %{
          label: "USD Value",
          data: Enum.map(fx_exposure, & &1.usd_value),
          backgroundColor: "#4a8c87"
        }
      ]
    }
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
