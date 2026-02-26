defmodule HoldcoWeb.WaterfallLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    statement = Finance.income_statement()

    {:ok,
     assign(socket,
       page_title: "Waterfall Chart",
       companies: companies,
       selected_company_id: "",
       date_from: "",
       date_to: "",
       statement: statement
     )}
  end

  @impl true
  def handle_event("filter", params, socket) do
    company_id =
      case Map.get(params, "company_id", "") do
        "" -> nil
        id -> String.to_integer(id)
      end

    date_from =
      case Map.get(params, "date_from", "") do
        "" -> nil
        d -> d
      end

    date_to =
      case Map.get(params, "date_to", "") do
        "" -> nil
        d -> d
      end

    statement = Finance.income_statement(company_id, date_from, date_to)

    {:noreply,
     assign(socket,
       selected_company_id: Map.get(params, "company_id", ""),
       date_from: Map.get(params, "date_from", ""),
       date_to: Map.get(params, "date_to", ""),
       statement: statement
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Waterfall Chart</h1>
          <p class="deck">Revenue flowing to expenses to net income</p>
        </div>
        <form phx-change="filter" style="display: flex; gap: 0.5rem; align-items: center; flex-wrap: wrap;">
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">All Companies</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @selected_company_id}>{c.name}</option>
              <% end %>
            </select>
          </div>
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">From</label>
            <input type="date" name="date_from" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;" value={@date_from} />
          </div>
          <div style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">To</label>
            <input type="date" name="date_to" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;" value={@date_to} />
          </div>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Revenue</div>
        <div class="metric-value num-positive">${format_number(@statement.total_revenue)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Expenses</div>
        <div class="metric-value num-negative">${format_number(@statement.total_expenses)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Net Income</div>
        <div class={"metric-value #{if @statement.net_income >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@statement.net_income)}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Waterfall</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="waterfall-chart"
          phx-hook="ChartHook"
          phx-update="ignore"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(waterfall_chart_data(@statement))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{display: true}},
              scales: %{
                x: %{stacked: true},
                y: %{stacked: true, beginAtZero: true}
              }
            })
          }
          style="height: 300px;"
        >
          <canvas></canvas>
        </div>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Revenue</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Code</th>
                <th>Account</th>
                <th class="th-num">Amount</th>
              </tr>
            </thead>
            <tbody>
              <%= for item <- @statement.revenue do %>
                <tr>
                  <td class="td-mono">{item.code}</td>
                  <td class="td-name">{item.name}</td>
                  <td class="td-num num-positive">{format_number(item.amount)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td></td>
                <td class="td-name">Total Revenue</td>
                <td class="td-num num-positive">{format_number(@statement.total_revenue)}</td>
              </tr>
            </tbody>
          </table>
          <%= if @statement.revenue == [] do %>
            <div class="empty-state">No revenue accounts found for this period.</div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Expenses</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Code</th>
                <th>Account</th>
                <th class="th-num">Amount</th>
              </tr>
            </thead>
            <tbody>
              <%= for item <- @statement.expenses do %>
                <tr>
                  <td class="td-mono">{item.code}</td>
                  <td class="td-name">{item.name}</td>
                  <td class="td-num num-negative">{format_number(item.amount)}</td>
                </tr>
              <% end %>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td></td>
                <td class="td-name">Total Expenses</td>
                <td class="td-num num-negative">{format_number(@statement.total_expenses)}</td>
              </tr>
            </tbody>
          </table>
          <%= if @statement.expenses == [] do %>
            <div class="empty-state">No expense accounts found for this period.</div>
          <% end %>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Income Summary</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Line Item</th>
              <th class="th-num">Amount</th>
            </tr>
          </thead>
          <tbody>
            <tr>
              <td class="td-name">Total Revenue</td>
              <td class="td-num num-positive">${format_number(@statement.total_revenue)}</td>
            </tr>
            <%= for exp <- @statement.expenses do %>
              <tr>
                <td class="td-name" style="padding-left: 2rem;">Less: {exp.name}</td>
                <td class="td-num num-negative">({format_number(exp.amount)})</td>
              </tr>
            <% end %>
            <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
              <td class="td-name">Net Income</td>
              <td class={"td-num #{if @statement.net_income >= 0, do: "num-positive", else: "num-negative"}"}>
                ${format_number(@statement.net_income)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp waterfall_chart_data(statement) do
    # Build waterfall: Revenue (green), each expense (red), Net Income (blue)
    # Using stacked bars to simulate waterfall effect:
    # - "Base" (invisible) dataset positions bars at the correct height
    # - "Value" dataset shows the actual bar

    revenue = statement.total_revenue
    expenses = statement.expenses
    net = statement.net_income

    labels = ["Revenue"] ++ Enum.map(expenses, & &1.name) ++ ["Net Income"]

    # Calculate running total for base positioning
    {base_values, _value_values} = build_waterfall_bars(revenue, expenses, net)

    %{
      labels: labels,
      datasets: [
        %{
          label: "Base",
          data: base_values,
          backgroundColor: "transparent",
          borderWidth: 0,
          stack: "waterfall"
        },
        %{
          label: "Revenue",
          data:
            [revenue] ++
              List.duplicate(0, length(expenses)) ++
              [if(net >= 0, do: net, else: 0)],
          backgroundColor: "#00994d",
          stack: "waterfall"
        },
        %{
          label: "Expense",
          data:
            [0] ++
              Enum.map(expenses, & &1.amount) ++
              [if(net < 0, do: abs(net), else: 0)],
          backgroundColor: "#cc0000",
          stack: "waterfall"
        }
      ]
    }
  end

  defp build_waterfall_bars(revenue, expenses, net) do
    # Base values: invisible bars that position visible bars at correct heights
    # Revenue bar starts at 0
    # Each expense bar starts at where the previous one ended
    # Net income bar starts at 0

    {_running, expense_bases} =
      Enum.reduce(expenses, {revenue, []}, fn exp, {running, bases} ->
        new_running = running - exp.amount
        {new_running, bases ++ [new_running]}
      end)

    base_values = [0] ++ expense_bases ++ [0]
    value_values = [revenue] ++ Enum.map(expenses, & &1.amount) ++ [net]

    {base_values, value_values}
  end

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
