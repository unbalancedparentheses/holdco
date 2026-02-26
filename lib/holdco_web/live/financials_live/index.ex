defmodule HoldcoWeb.FinancialsLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Holdco.Platform.subscribe("finance")

    financials = Finance.list_financials()
    companies = Corporate.list_companies()
    total_revenue = Finance.total_revenue()
    total_expenses = Finance.total_expenses()
    total_liabilities = Finance.total_liabilities()

    {:ok, assign(socket,
      page_title: "Financials",
      financials: financials,
      companies: companies,
      total_revenue: total_revenue,
      total_expenses: total_expenses,
      total_liabilities: total_liabilities,
      show_form: false
    )}
  end

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save", %{"financial" => params}, socket) do
    case Finance.create_financial(params) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Financial record added") |> assign(show_form: false)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add record")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    financial = Finance.get_financial!(String.to_integer(id))
    Finance.delete_financial(financial)
    {:noreply, reload(socket) |> put_flash(:info, "Financial record deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    financials = Finance.list_financials()
    total_revenue = Finance.total_revenue()
    total_expenses = Finance.total_expenses()
    total_liabilities = Finance.total_liabilities()
    assign(socket, financials: financials, total_revenue: total_revenue, total_expenses: total_expenses, total_liabilities: total_liabilities)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Financials</h1>
          <p class="deck">P&L across all companies and periods</p>
        </div>
        <button class="btn btn-primary" phx-click="show_form">Add Period</button>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Revenue</div>
        <div class="metric-value num-positive">$<%= format_number(@total_revenue) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Expenses</div>
        <div class="metric-value num-negative">$<%= format_number(@total_expenses) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Income</div>
        <div class={"metric-value #{if @total_revenue - @total_expenses >= 0, do: "num-positive", else: "num-negative"}"}>$<%= format_number(@total_revenue - @total_expenses) %></div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Liabilities</div>
        <div class="metric-value num-negative">$<%= format_number(@total_liabilities) %></div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>P&L Trend</h2></div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="pl-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(pl_chart_data(@financials))}
          data-chart-options={Jason.encode!(%{plugins: %{legend: %{display: true}}, scales: %{y: %{beginAtZero: true}}})}
          style="height: 250px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>All Periods</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th>Company</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net</th>
              <th>Currency</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for f <- @financials do %>
              <% net = (f.revenue || 0) - (f.expenses || 0) %>
              <tr>
                <td class="td-mono"><%= f.period %></td>
                <td><%= if f.company, do: f.company.name, else: "---" %></td>
                <td class="td-num num-positive"><%= format_number(f.revenue || 0) %></td>
                <td class="td-num num-negative"><%= format_number(f.expenses || 0) %></td>
                <td class={"td-num #{if net >= 0, do: "num-positive", else: "num-negative"}"}><%= format_number(net) %></td>
                <td><%= f.currency %></td>
                <td><button phx-click="delete" phx-value-id={f.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @financials == [] do %>
          <div class="empty-state">No financial records yet.</div>
        <% end %>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Financial Period</h3></div>
          <div class="modal-body">
            <form phx-submit="save">
              <div class="form-group">
                <label class="form-label">Company *</label>
                <select name="financial[company_id]" class="form-select" required>
                  <option value="">Select company</option>
                  <%= for c <- @companies do %><option value={c.id}><%= c.name %></option><% end %>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Period *</label><input type="text" name="financial[period]" class="form-input" placeholder="e.g. 2025-Q1" required /></div>
              <div class="form-group"><label class="form-label">Revenue</label><input type="number" name="financial[revenue]" class="form-input" step="any" value="0" /></div>
              <div class="form-group"><label class="form-label">Expenses</label><input type="number" name="financial[expenses]" class="form-input" step="any" value="0" /></div>
              <div class="form-group"><label class="form-label">Currency</label><input type="text" name="financial[currency]" class="form-input" value="USD" /></div>
              <div class="form-group"><label class="form-label">Notes</label><textarea name="financial[notes]" class="form-input"></textarea></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Period</button>
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

  defp pl_chart_data(financials) do
    sorted = financials |> Enum.sort_by(& &1.period)
    %{
      labels: Enum.map(sorted, & &1.period),
      datasets: [
        %{label: "Revenue", data: Enum.map(sorted, & &1.revenue), backgroundColor: "#00994d"},
        %{label: "Expenses", data: Enum.map(sorted, & &1.expenses), backgroundColor: "#cc0000"}
      ]
    }
  end
end
