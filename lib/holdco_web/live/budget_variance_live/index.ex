defmodule HoldcoWeb.BudgetVarianceLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    budgets = Finance.list_budgets()

    {total_budgeted, total_actual, categories} = compute_summary(budgets)

    {:ok,
     assign(socket,
       page_title: "Budget vs Actual",
       companies: companies,
       all_budgets: budgets,
       budgets: budgets,
       selected_company_id: "",
       total_budgeted: total_budgeted,
       total_actual: total_actual,
       categories: categories
     )}
  end

  @impl true
  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_company", %{"company_id" => id}, socket) do
    filtered =
      if id == "" do
        socket.assigns.all_budgets
      else
        company_id = String.to_integer(id)
        Enum.filter(socket.assigns.all_budgets, &(&1.company_id == company_id))
      end

    {total_budgeted, total_actual, categories} = compute_summary(filtered)

    {:noreply,
     assign(socket,
       selected_company_id: id,
       budgets: filtered,
       total_budgeted: total_budgeted,
       total_actual: total_actual,
       categories: categories
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="page-title">
      <div style="display: flex; justify-content: space-between; align-items: flex-start;">
        <div>
          <h1>Budget vs Actual</h1>
          <p class="deck">
            Compare budgeted amounts against actual spend across all categories and entities
          </p>
        </div>
        <form phx-change="filter_company" style="display: flex; align-items: center; gap: 0.5rem;">
          <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
          <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
            <option value="">All Companies</option>
            <%= for c <- @companies do %>
              <option value={c.id} selected={to_string(c.id) == @selected_company_id}>
                {c.name}
              </option>
            <% end %>
          </select>
        </form>
      </div>
      <hr class="page-title-rule" />
    </div>

    <% total_variance = Money.sub(@total_actual, @total_budgeted) %>
    <% variance_pct = if Money.gt?(@total_budgeted, 0), do: Money.mult(Money.div(total_variance, @total_budgeted), 100), else: Decimal.new(0) %>
    <% overruns = Enum.filter(@categories, fn cat -> Money.gt?(cat.actual, cat.budgeted) end) %>
    <% largest_overrun = if overruns != [], do: Enum.max_by(overruns, fn cat -> Money.to_float(Money.sub(cat.actual, cat.budgeted)) end), else: nil %>
    <div class="metrics-strip">
      <div class="metric-cell">
        <div class="metric-label">Total Budgeted</div>
        <div class="metric-value">${format_number(@total_budgeted)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Total Actual</div>
        <div class="metric-value">${format_number(@total_actual)}</div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Variance ($)</div>
        <div class={"metric-value #{variance_class(total_variance)}"}>
          {variance_sign(total_variance)}{format_number(Money.abs(total_variance))}
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Variance (%)</div>
        <div class={"metric-value #{variance_class(total_variance)}"}>
          {variance_sign(total_variance)}{Money.to_float(Money.round(Money.abs(variance_pct), 1))}%
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Largest Overrun</div>
        <div class="metric-value num-negative">
          <%= if largest_overrun do %>
            {largest_overrun.category}: +${format_number(Money.sub(largest_overrun.actual, largest_overrun.budgeted))}
          <% else %>
            None
          <% end %>
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-label">Categories Over Budget</div>
        <div class={"metric-value #{if length(overruns) > 0, do: "num-negative", else: "num-positive"}"}>
          {length(overruns)}
        </div>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>Budget vs Actual by Category</h2>
      </div>
      <div class="panel" style="padding: 1rem;">
        <div
          id="budget-variance-chart"
          phx-hook="ChartHook"
          data-chart-type="bar"
          data-chart-data={Jason.encode!(budget_chart_data(@categories))}
          data-chart-options={
            Jason.encode!(%{
              plugins: %{legend: %{display: true}},
              scales: %{y: %{beginAtZero: true}}
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
        <h2>Variance Detail</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Category</th>
              <th class="th-num">Budgeted</th>
              <th class="th-num">Actual</th>
              <th class="th-num">Variance ($)</th>
              <th class="th-num">Variance (%)</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <%= for cat <- @categories do %>
              <% var = Money.sub(cat.actual, cat.budgeted) %>
              <% var_pct = if Money.gt?(cat.budgeted, 0), do: Money.mult(Money.div(var, cat.budgeted), 100), else: Decimal.new(0) %>
              <tr>
                <td class="td-name">{cat.category}</td>
                <td class="td-num">${format_number(cat.budgeted)}</td>
                <td class="td-num">${format_number(cat.actual)}</td>
                <td class={"td-num #{variance_class(var)}"}>
                  {variance_sign(var)}{format_number(Money.abs(var))}
                </td>
                <td class={"td-num #{variance_class(var)}"}>
                  {variance_sign(var)}{Money.to_float(Money.round(Money.abs(var_pct), 1))}%
                </td>
                <td>
                  <%= cond do %>
                    <% Money.positive?(var) -> %>
                      <span class="tag tag-crimson">Over Budget</span>
                    <% Money.negative?(var) -> %>
                      <span class="tag tag-jade">Under Budget</span>
                    <% true -> %>
                      <span class="tag tag-ink">On Budget</span>
                  <% end %>
                </td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @categories == [] do %>
          <div class="empty-state">
            No budget records found. Add budget entries in the Financials section to see variance analysis.
          </div>
        <% end %>
      </div>
    </div>

    <div class="section">
      <div class="section-head">
        <h2>All Budget Records</h2>
      </div>
      <div class="panel">
        <table>
          <thead>
            <tr>
              <th>Period</th>
              <th>Category</th>
              <th>Company</th>
              <th class="th-num">Budgeted</th>
              <th class="th-num">Actual</th>
              <th class="th-num">Variance</th>
              <th>Currency</th>
            </tr>
          </thead>
          <tbody>
            <%= for b <- @budgets do %>
              <% var = Money.sub(Money.to_decimal(b.actual), Money.to_decimal(b.budgeted)) %>
              <tr>
                <td class="td-mono">{b.period}</td>
                <td class="td-name">{b.category}</td>
                <td>
                  <%= if b.company do %>
                    <.link navigate={~p"/companies/#{b.company.id}"} class="td-link">
                      {b.company.name}
                    </.link>
                  <% else %>
                    ---
                  <% end %>
                </td>
                <td class="td-num">{format_number(b.budgeted || 0)}</td>
                <td class="td-num">{format_number(b.actual || 0)}</td>
                <td class={"td-num #{variance_class(var)}"}>
                  {variance_sign(var)}{format_number(Money.abs(var))}
                </td>
                <td>{b.currency}</td>
              </tr>
            <% end %>
          </tbody>
        </table>
        <%= if @budgets == [] do %>
          <div class="empty-state">No budget records found.</div>
        <% end %>
      </div>
    </div>
    """
  end

  # -- Helpers --

  defp compute_summary(budgets) do
    total_budgeted = Enum.reduce(budgets, Decimal.new(0), fn b, acc -> Money.add(acc, Money.to_decimal(b.budgeted)) end)
    total_actual = Enum.reduce(budgets, Decimal.new(0), fn b, acc -> Money.add(acc, Money.to_decimal(b.actual)) end)

    categories =
      budgets
      |> Enum.group_by(& &1.category)
      |> Enum.map(fn {category, items} ->
        budgeted = Enum.reduce(items, Decimal.new(0), fn b, acc -> Money.add(acc, Money.to_decimal(b.budgeted)) end)
        actual = Enum.reduce(items, Decimal.new(0), fn b, acc -> Money.add(acc, Money.to_decimal(b.actual)) end)
        %{category: category || "Uncategorized", budgeted: budgeted, actual: actual}
      end)
      |> Enum.sort_by(& &1.category)

    {total_budgeted, total_actual, categories}
  end

  defp budget_chart_data(categories) do
    %{
      labels: Enum.map(categories, & &1.category),
      datasets: [
        %{
          label: "Budgeted",
          data: Enum.map(categories, &Money.to_float(&1.budgeted)),
          backgroundColor: "#4a8c87"
        },
        %{
          label: "Actual",
          data: Enum.map(categories, &Money.to_float(&1.actual)),
          backgroundColor:
            Enum.map(categories, fn cat ->
              if Money.gt?(cat.actual, cat.budgeted), do: "#cc0000", else: "#00994d"
            end)
        }
      ]
    }
  end

  defp variance_class(var) do
    cond do
      Money.positive?(var) -> "num-negative"
      Money.negative?(var) -> "num-positive"
      true -> ""
    end
  end

  defp variance_sign(var) do
    cond do
      Money.positive?(var) -> "+"
      Money.negative?(var) -> "-"
      true -> ""
    end
  end

  defp format_number(%Decimal{} = n),
    do: n |> Decimal.round(0) |> Decimal.to_string() |> add_commas()

  defp format_number(n) when is_float(n),
    do: Money.to_float(Money.round(n, 0)) |> :erlang.float_to_binary(decimals: 0) |> add_commas()

  defp format_number(n) when is_integer(n), do: Integer.to_string(n) |> add_commas()
  defp format_number(_), do: "0"

  defp add_commas(str) do
    str |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
  end
end
