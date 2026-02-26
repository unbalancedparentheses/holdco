defmodule HoldcoWeb.CashForecastLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Banking, Finance, Compliance, Portfolio}

  @months_ahead 12

  @impl true
  def mount(_params, _session, socket) do
    today = Date.utc_today()
    transactions = Banking.list_transactions()
    bank_accounts = Banking.list_bank_accounts()
    liabilities = Finance.list_liabilities()
    tax_deadlines = Compliance.list_tax_deadlines()

    current_cash =
      Enum.reduce(bank_accounts, 0.0, fn ba, acc ->
        acc + Portfolio.to_usd(ba.balance || 0.0, ba.currency)
      end)

    recurring = detect_recurring(transactions)
    recurring_income = Enum.filter(recurring, &(&1.avg_amount > 0))
    recurring_expenses = Enum.filter(recurring, &(&1.avg_amount < 0))

    monthly_recurring_inflow =
      Enum.reduce(recurring_income, 0.0, fn r, acc -> acc + r.avg_amount end)

    monthly_recurring_outflow =
      Enum.reduce(recurring_expenses, 0.0, fn r, acc -> acc + abs(r.avg_amount) end)

    one_time_expenses = build_one_time_expenses(liabilities, tax_deadlines, today)
    projections = project_monthly(current_cash, monthly_recurring_inflow, monthly_recurring_outflow, one_time_expenses, today)

    eoq = end_of_quarter_balance(projections, today)
    eoy = end_of_year_balance(projections, today)

    {:ok,
     assign(socket,
       page_title: "Cash Flow Forecast",
       today: today,
       current_cash: current_cash,
       projected_eoq: eoq,
       projected_eoy: eoy,
       recurring_income: recurring_income,
       recurring_expenses: recurring_expenses,
       one_time_expenses: one_time_expenses,
       projections: projections,
       monthly_recurring_inflow: monthly_recurring_inflow,
       monthly_recurring_outflow: monthly_recurring_outflow
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <h1>Cash Flow Forecast</h1>
      <p class="deck">
        12-month cash flow projection based on recurring transaction patterns, liability maturities, and tax deadlines
      </p>
      <hr class="page-title-rule" />
    </div>

    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Current Cash Position</div>
        <div class={"metric-value #{if @current_cash >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@current_cash)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Projected End of Quarter</div>
        <div class={"metric-value #{if @projected_eoq >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@projected_eoq)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Projected End of Year</div>
        <div class={"metric-value #{if @projected_eoy >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(@projected_eoy)}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Monthly Net Cash Flow</div>
        <% net_monthly = @monthly_recurring_inflow - @monthly_recurring_outflow %>
        <div class={"metric-value #{if net_monthly >= 0, do: "num-positive", else: "num-negative"}"}>
          ${format_number(net_monthly)}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Projected Cash Flow</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="cash-forecast-chart"
          phx-hook="ChartHook"
          data-chart-type="line"
          data-chart-data={Jason.encode!(forecast_chart_data(@projections))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{position: "top"}},
              scales: %{
                y: %{
                  beginAtZero: false,
                  title: %{display: true, text: "USD"}
                }
              },
              elements: %{point: %{radius: 4}, line: %{tension: 0.3}}
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
        <h2>Monthly Projections</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Month</th>
              <th class="th-num">Inflows</th>
              <th class="th-num">Outflows</th>
              <th class="th-num">One-Time</th>
              <th class="th-num">Net</th>
              <th class="th-num">Ending Balance</th>
            </tr>
          </thead>
          <tbody>
            <%= for p <- @projections do %>
              <tr>
                <td class="td-mono">{p.label}</td>
                <td class="td-num num-positive">${format_number(p.inflows)}</td>
                <td class="td-num num-negative">${format_number(p.outflows)}</td>
                <td class={"td-num #{if p.one_time < 0, do: "num-negative", else: ""}"}>
                  <%= if p.one_time != 0.0 do %>
                    ${format_number(p.one_time)}
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class={"td-num #{if p.net >= 0, do: "num-positive", else: "num-negative"}"}>
                  ${format_number(p.net)}
                </td>
                <td class={"td-num #{if p.ending_balance >= 0, do: "num-positive", else: "num-negative"}"} style="font-weight: 600;">
                  ${format_number(p.ending_balance)}
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @projections == [] do %>
          <div class="empty-state">No projection data available.</div>
        <% end %>
      </div>
    </div>

    <div class="grid-2">
      <div class="section">
        <div class="section-head">
          <h2>Recurring Income</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Description</th>
                <th class="th-num">Avg Amount</th>
                <th class="th-num">Occurrences</th>
              </tr>
            </thead>
            <tbody>
              <%= for r <- @recurring_income do %>
                <tr>
                  <td class="td-name">{r.description}</td>
                  <td class="td-num num-positive">${format_number(r.avg_amount)}</td>
                  <td class="td-num">{r.count}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td class="td-name">Total Monthly Inflow</td>
                <td class="td-num num-positive">${format_number(@monthly_recurring_inflow)}</td>
                <td></td>
              </tr>
            </tfoot>
          </table>
          <%= if @recurring_income == [] do %>
            <div class="empty-state">
              No recurring income patterns detected. Patterns require 3+ transactions with the same description.
            </div>
          <% end %>
        </div>
      </div>

      <div class="section">
        <div class="section-head">
          <h2>Recurring Expenses</h2>
        </div>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Description</th>
                <th class="th-num">Avg Amount</th>
                <th class="th-num">Occurrences</th>
              </tr>
            </thead>
            <tbody>
              <%= for r <- @recurring_expenses do %>
                <tr>
                  <td class="td-name">{r.description}</td>
                  <td class="td-num num-negative">${format_number(r.avg_amount)}</td>
                  <td class="td-num">{r.count}</td>
                </tr>
              <% end %>
            </tbody>
            <tfoot>
              <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                <td class="td-name">Total Monthly Outflow</td>
                <td class="td-num num-negative">${format_number(-@monthly_recurring_outflow)}</td>
                <td></td>
              </tr>
            </tfoot>
          </table>
          <%= if @recurring_expenses == [] do %>
            <div class="empty-state">
              No recurring expense patterns detected. Patterns require 3+ transactions with the same description.
            </div>
          <% end %>
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Known One-Time Expenses</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Description</th>
              <th>Type</th>
              <th>Due Date</th>
              <th class="th-num">Amount (USD)</th>
            </tr>
          </thead>
          <tbody>
            <%= for e <- @one_time_expenses do %>
              <tr>
                <td class="td-name">{e.description}</td>
                <td>
                  <span class={"tag #{one_time_tag(e.type)}"}>{e.type}</span>
                </td>
                <td class="td-mono">{e.due_date}</td>
                <td class="td-num num-negative">${format_number(e.amount)}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @one_time_expenses == [] do %>
          <div class="empty-state">
            No upcoming one-time expenses. Add liabilities or tax deadlines to see scheduled outflows.
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Recurring Detection --

  defp detect_recurring(transactions) do
    transactions
    |> Enum.filter(&(&1.description != nil and &1.description != ""))
    |> Enum.group_by(& &1.description)
    |> Enum.filter(fn {_desc, txns} -> length(txns) >= 3 end)
    |> Enum.map(fn {desc, txns} ->
      avg_amount = Enum.reduce(txns, 0.0, fn t, acc -> (t.amount || 0.0) + acc end) / length(txns)
      %{description: desc, avg_amount: avg_amount, count: length(txns)}
    end)
    |> Enum.sort_by(&abs(&1.avg_amount), :desc)
  end

  # -- One-Time Expenses --

  defp build_one_time_expenses(liabilities, tax_deadlines, today) do
    today_str = Date.to_iso8601(today)
    end_date = today |> Date.add(@months_ahead * 30) |> Date.to_iso8601()

    liability_expenses =
      liabilities
      |> Enum.filter(fn l ->
        l.status == "active" and l.maturity_date != nil and l.maturity_date != "" and
          l.maturity_date >= today_str and l.maturity_date <= end_date
      end)
      |> Enum.map(fn l ->
        %{
          description: "#{l.creditor} - #{l.liability_type} maturity",
          type: "Liability",
          due_date: l.maturity_date,
          amount: Portfolio.to_usd(l.principal || 0.0, l.currency)
        }
      end)

    tax_expenses =
      tax_deadlines
      |> Enum.filter(fn td ->
        td.status in ["pending", "upcoming"] and
          td.due_date != nil and td.due_date != "" and
          td.due_date >= today_str and td.due_date <= end_date
      end)
      |> Enum.map(fn td ->
        %{
          description: "#{td.description} (#{td.jurisdiction})",
          type: "Tax",
          due_date: td.due_date,
          amount: td.estimated_amount || 0.0
        }
      end)

    (liability_expenses ++ tax_expenses)
    |> Enum.sort_by(& &1.due_date)
  end

  # -- Monthly Projections --

  defp project_monthly(current_cash, monthly_inflow, monthly_outflow, one_time_expenses, today) do
    Enum.map(0..(@months_ahead - 1), fn offset ->
      month_date = Date.add(today, offset * 30)
      year = month_date.year
      month = month_date.month
      label = "#{year}-#{String.pad_leading(Integer.to_string(month), 2, "0")}"

      one_time_for_month =
        one_time_expenses
        |> Enum.filter(fn e ->
          case Date.from_iso8601(e.due_date) do
            {:ok, d} -> d.year == year and d.month == month
            _ -> false
          end
        end)
        |> Enum.reduce(0.0, fn e, acc -> acc - e.amount end)

      %{
        label: label,
        month_offset: offset,
        inflows: monthly_inflow,
        outflows: monthly_outflow,
        one_time: one_time_for_month,
        net: 0.0,
        ending_balance: 0.0
      }
    end)
    |> compute_running_balance(current_cash)
  end

  defp compute_running_balance(projections, starting_balance) do
    {result, _} =
      Enum.map_reduce(projections, starting_balance, fn p, balance ->
        net = p.inflows - p.outflows + p.one_time
        ending = balance + net
        {%{p | net: net, ending_balance: ending}, ending}
      end)

    result
  end

  # -- End of Quarter / Year --

  defp end_of_quarter_balance(projections, today) do
    quarter_end_month = ceil(today.month / 3) * 3
    quarter_end_label = "#{today.year}-#{String.pad_leading(Integer.to_string(quarter_end_month), 2, "0")}"

    case Enum.find(projections, fn p -> p.label == quarter_end_label end) do
      nil -> List.last(projections)[:ending_balance] || 0.0
      p -> p.ending_balance
    end
  end

  defp end_of_year_balance(projections, today) do
    eoy_label = "#{today.year}-12"

    case Enum.find(projections, fn p -> p.label == eoy_label end) do
      nil -> List.last(projections)[:ending_balance] || 0.0
      p -> p.ending_balance
    end
  end

  # -- Chart Data --

  defp forecast_chart_data(projections) do
    %{
      labels: Enum.map(projections, & &1.label),
      datasets: [
        %{
          label: "Ending Balance",
          data: Enum.map(projections, & &1.ending_balance),
          borderColor: "#4a8c87",
          backgroundColor: "rgba(74, 140, 135, 0.1)",
          fill: true
        },
        %{
          label: "Inflows",
          data: Enum.map(projections, & &1.inflows),
          borderColor: "#5f8f6e",
          backgroundColor: "transparent",
          borderDash: [5, 5]
        },
        %{
          label: "Outflows",
          data: Enum.map(projections, fn p -> -p.outflows end),
          borderColor: "#b0605e",
          backgroundColor: "transparent",
          borderDash: [5, 5]
        }
      ]
    }
  end

  # -- Formatting --

  defp one_time_tag("Liability"), do: "tag-crimson"
  defp one_time_tag("Tax"), do: "tag-lemon"
  defp one_time_tag(_), do: "tag-ink"

  defp format_number(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
