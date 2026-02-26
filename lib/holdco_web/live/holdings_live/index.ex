defmodule HoldcoWeb.HoldingsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Assets, Corporate, Portfolio}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("portfolio")

    holdings = Assets.list_holdings()
    companies = Corporate.list_companies()
    allocation = Portfolio.asset_allocation()
    total_value = Enum.reduce(holdings, 0.0, fn h, acc -> acc + (h.quantity || 0.0) end)

    {:ok, assign(socket,
      page_title: "Holdings",
      holdings: holdings,
      companies: companies,
      allocation: allocation,
      total_value: total_value,
      show_form: false
    )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", %{"holding" => params}, socket) do
    case Assets.create_holding(params) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Holding added") |> assign(show_form: false)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add holding")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    holding = Assets.get_holding!(String.to_integer(id))
    Assets.delete_holding(holding)
    {:noreply, reload(socket) |> put_flash(:info, "Holding deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    holdings = Assets.list_holdings()
    allocation = Portfolio.asset_allocation()
    total_value = Enum.reduce(holdings, 0.0, fn h, acc -> acc + (h.quantity || 0.0) end)
    assign(socket, holdings: holdings, allocation: allocation, total_value: total_value)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Holdings</h1>
          <p class="deck"><%= length(@holdings) %> positions across all entities</p>
        </div>
        <button class="btn btn-primary" phx-click="show_form">Add Holding</button>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Positions</div>
        <div class="metric-value"><%= length(@holdings) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Quantity Value</div>
        <div class="metric-value"><%= format_number(@total_value) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Asset Types</div>
        <div class="metric-value"><%= length(@allocation) %></div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head"><h2>Allocation by Type</h2></div>
        <div class="panel" style="padding: 1rem;">
          <div
            id="holdings-allocation-chart"
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
        <div class="section-head"><h2>By Type Summary</h2></div>
        <div class="panel">
          <table>
            <thead><tr><th>Type</th><th class="th-num">Count</th><th class="th-num">Total Qty</th></tr></thead>
            <tbody>
              <%= for a <- @allocation do %>
                <tr>
                  <td><span class="tag tag-ink"><%= a.type %></span></td>
                  <td class="td-num"><%= a.count %></td>
                  <td class="td-num"><%= format_number(a.value || 0) %></td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Holdings</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Asset</th>
              <th>Ticker</th>
              <th class="th-num">Qty</th>
              <th>Unit</th>
              <th>Type</th>
              <th>Currency</th>
              <th>Company</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for h <- @holdings do %>
              <tr>
                <td class="td-name"><%= h.asset %></td>
                <td class="td-mono"><%= h.ticker %></td>
                <td class="td-num"><%= h.quantity %></td>
                <td><%= h.unit %></td>
                <td><span class="tag tag-ink"><%= h.asset_type %></span></td>
                <td><%= h.currency %></td>
                <td><%= if h.company, do: h.company.name, else: "---" %></td>
                <td><button phx-click="delete" phx-value-id={h.id} class="btn btn-danger btn-sm" data-confirm="Delete this holding?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @holdings == [] do %>
          <div class="empty-state">No holdings yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Holding</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="holding[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Asset Name *</label><input type="text" name="holding[asset]" class="form-input" required /></div>
              <div class="form-group"><label class="form-label">Ticker</label><input type="text" name="holding[ticker]" class="form-input" /></div>
              <div class="form-group"><label class="form-label">Quantity</label><input type="number" name="holding[quantity]" class="form-input" step="any" /></div>
              <div class="form-group"><label class="form-label">Unit</label><input type="text" name="holding[unit]" class="form-input" /></div>
              <div class="form-group">
                <label class="form-label">Asset Type</label>
                <select name="holding[asset_type]" class="form-select">
                  <option value="stock">Stock</option><option value="etf">ETF</option><option value="crypto">Crypto</option>
                  <option value="commodity">Commodity</option><option value="bond">Bond</option><option value="real_estate">Real Estate</option>
                  <option value="private_equity">Private Equity</option><option value="fund">Fund</option><option value="other">Other</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Currency</label><input type="text" name="holding[currency]" class="form-input" value="USD" /></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Holding</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()
  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end

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
end
