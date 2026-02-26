defmodule HoldcoWeb.ScenarioLive.Show do
  use HoldcoWeb, :live_view

  alias Holdco.Scenarios

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: Scenarios.subscribe()

    scenario = Scenarios.get_scenario!(id)
    projection = Scenarios.project(scenario)

    {:ok, assign(socket,
      page_title: scenario.name,
      scenario: scenario,
      projection: projection,
      show_form: false
    )}
  end

  @impl true
  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("show_form", _, socket), do: {:noreply, assign(socket, show_form: true)}
  def handle_event("close_form", _, socket), do: {:noreply, assign(socket, show_form: false)}

  def handle_event("save_item", %{"item" => params}, socket) do
    params = Map.put(params, "scenario_id", socket.assigns.scenario.id)
    case Scenarios.create_scenario_item(params) do
      {:ok, _} -> {:noreply, reload(socket) |> put_flash(:info, "Item added") |> assign(show_form: false)}
      {:error, _} -> {:noreply, put_flash(socket, :error, "Failed to add item")}
    end
  end

  def handle_event("delete_item", %{"id" => id}, socket) do
    item = Scenarios.get_scenario_item!(id)
    Scenarios.delete_scenario_item(item)
    {:noreply, reload(socket) |> put_flash(:info, "Item deleted")}
  end

  @impl true
  def handle_info(_, socket), do: {:noreply, reload(socket)}

  defp reload(socket) do
    scenario = Scenarios.get_scenario!(socket.assigns.scenario.id)
    projection = Scenarios.project(scenario)
    assign(socket, scenario: scenario, projection: projection)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1><%= @scenario.name %></h1>
          <p class="deck">
            <%= @scenario.description || "Financial projection" %>
            &mdash; <%= @scenario.projection_months %> months
            <%= if @scenario.company, do: " for #{@scenario.company.name}" %>
          </p>
        </div>
        <.link navigate={~p"/scenarios"} class="btn btn-secondary">Back to Scenarios</.link>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Scenario Items</h2>
        <button class="btn btn-sm btn-primary" phx-click="show_form">Add Item</button>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Name</th>
              <th>Type</th>
              <th class="th-num">Amount</th>
              <th>Growth</th>
              <th>Recurrence</th>
              <th>Probability</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            <%= for item <- @scenario.items do %>
              <tr>
                <td class="td-name"><%= item.name %></td>
                <td><span class={"tag #{if item.item_type == "revenue", do: "tag-jade", else: "tag-crimson"}"}><%= item.item_type %></span></td>
                <td class="td-num"><%= item.amount %> <%= item.currency %></td>
                <td class="td-num"><%= item.growth_rate %>% (<%= item.growth_type %>)</td>
                <td><%= item.recurrence %></td>
                <td class="td-num"><%= Float.round((item.probability || 1.0) * 100, 0) %>%</td>
                <td><button phx-click="delete_item" phx-value-id={item.id} class="btn btn-danger btn-sm" data-confirm="Delete?">Del</button></td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @scenario.items == [] do %>
          <div class="empty-state">No items yet. Add revenue and expense items to build the projection.</div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Projection Chart</h2></div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="projection-chart"
          phx-hook="ChartHook"
          data-chart-type="line"
          data-chart-data={Jason.encode!(projection_chart_data(@projection))}
          data-chart-options={Jason.encode!(%{plugins: %{legend: %{display: true}}, scales: %{y: %{beginAtZero: true}}})}
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head"><h2>Monthly Projections</h2></div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Month</th>
              <th class="th-num">Revenue</th>
              <th class="th-num">Expenses</th>
              <th class="th-num">Net</th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @projection do %>
              <tr>
                <td class="td-mono">Month <%= p.month %></td>
                <td class="td-num num-positive"><%= format_number(p.revenue) %></td>
                <td class="td-num num-negative"><%= format_number(p.expenses) %></td>
                <td class={"td-num #{if p.net >= 0, do: "num-positive", else: "num-negative"}"}><%= format_number(p.net) %></td>
              </tr>
            <% end %>
          </tbody>
          <tfoot>
            <tr>
              <td><strong>Total</strong></td>
              <td class="td-num num-positive"><strong><%= format_number(Enum.reduce(@projection, 0.0, fn p, a -> a + p.revenue end)) %></strong></td>
              <td class="td-num num-negative"><strong><%= format_number(Enum.reduce(@projection, 0.0, fn p, a -> a + p.expenses end)) %></strong></td>
              <td class={"td-num #{if Enum.reduce(@projection, 0.0, fn p, a -> a + p.net end) >= 0, do: "num-positive", else: "num-negative"}"}><strong><%= format_number(Enum.reduce(@projection, 0.0, fn p, a -> a + p.net end)) %></strong></td>
            </tr>
          </tfoot>
        </table>
      </div>
    </div>

    <%= if @show_form do %>
      <div class="modal-overlay" phx-click="close_form">
        <div class="modal" phx-click-away="close_form">
          <div class="modal-header"><h3>Add Scenario Item</h3></div>
          <div class="modal-body">
            <form phx-submit="save_item">
              <div class="form-group"><label class="form-label">Name *</label><input type="text" name="item[name]" class="form-input" required /></div>
              <div class="form-group">
                <label class="form-label">Type</label>
                <select name="item[item_type]" class="form-select">
                  <option value="revenue">Revenue</option>
                  <option value="expense">Expense</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Monthly Amount</label><input type="number" name="item[amount]" class="form-input" step="any" value="0" /></div>
              <div class="form-group"><label class="form-label">Currency</label><input type="text" name="item[currency]" class="form-input" value="USD" /></div>
              <div class="form-group"><label class="form-label">Growth Rate %</label><input type="number" name="item[growth_rate]" class="form-input" step="any" value="0" /></div>
              <div class="form-group">
                <label class="form-label">Growth Type</label>
                <select name="item[growth_type]" class="form-select">
                  <option value="linear">Linear</option>
                  <option value="compound">Compound</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Recurrence</label>
                <select name="item[recurrence]" class="form-select">
                  <option value="monthly">Monthly</option>
                  <option value="quarterly">Quarterly</option>
                  <option value="annually">Annually</option>
                </select>
              </div>
              <div class="form-group"><label class="form-label">Probability (0-1)</label><input type="number" name="item[probability]" class="form-input" step="0.01" min="0" max="1" value="1" /></div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">Add Item</button>
                <button type="button" phx-click="close_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 2) |> add_commas()
  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    {decimal_part, integer_part} =
      case String.split(str, ".") do
        [int, dec] -> {"." <> dec, int}
        [int] -> {"", int}
      end

    formatted =
      integer_part
      |> String.reverse()
      |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
      |> String.reverse()

    formatted <> decimal_part
  end

  defp projection_chart_data(projection) do
    %{
      labels: Enum.map(projection, fn p -> "Month #{p.month}" end),
      datasets: [
        %{label: "Revenue", data: Enum.map(projection, & &1.revenue), borderColor: "#00994d", backgroundColor: "rgba(0, 153, 77, 0.1)", fill: false, tension: 0.3},
        %{label: "Expenses", data: Enum.map(projection, & &1.expenses), borderColor: "#cc0000", backgroundColor: "rgba(204, 0, 0, 0.1)", fill: false, tension: 0.3},
        %{label: "Net", data: Enum.map(projection, & &1.net), borderColor: "#0d7680", backgroundColor: "rgba(13, 118, 128, 0.1)", fill: true, tension: 0.3}
      ]
    }
  end
end
