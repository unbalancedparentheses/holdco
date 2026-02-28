defmodule HoldcoWeb.WaterfallLive.Index do
  use HoldcoWeb, :live_view

  alias Holdco.{Finance, Fund, Corporate}
  alias Holdco.Money

  @impl true
  def mount(_params, _session, socket) do
    companies = Corporate.list_companies()
    statement = Finance.income_statement()

    if connected?(socket), do: Fund.subscribe()

    {:ok,
     assign(socket,
       page_title: "Waterfall Chart",
       companies: companies,
       selected_company_id: "",
       date_from: "",
       date_to: "",
       statement: statement,
       # Fund waterfall tier management
       waterfall_tiers: [],
       tier_company_id: "",
       show_tier_form: false,
       editing_tier: nil,
       waterfall_calc_amount: "",
       waterfall_calc_capital: "",
       waterfall_results: nil
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

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("filter_tier_company", %{"company_id" => id}, socket) do
    if id == "" do
      {:noreply, assign(socket, tier_company_id: "", waterfall_tiers: [], waterfall_results: nil)}
    else
      company_id = String.to_integer(id)
      tiers = Fund.list_waterfall_tiers(company_id)
      {:noreply, assign(socket, tier_company_id: id, waterfall_tiers: tiers, waterfall_results: nil)}
    end
  end

  def handle_event("show_tier_form", _, socket) do
    {:noreply, assign(socket, show_tier_form: :add, editing_tier: nil)}
  end

  def handle_event("close_tier_form", _, socket) do
    {:noreply, assign(socket, show_tier_form: false, editing_tier: nil)}
  end

  def handle_event("edit_tier", %{"id" => id}, socket) do
    tier = Fund.get_waterfall_tier!(String.to_integer(id))
    {:noreply, assign(socket, show_tier_form: :edit, editing_tier: tier)}
  end

  def handle_event("save_tier", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("update_tier", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("delete_tier", _params, %{assigns: %{can_write: false}} = socket) do
    {:noreply, put_flash(socket, :error, "You don't have permission to do that")}
  end

  def handle_event("save_tier", %{"tier" => params}, socket) do
    params = Map.put(params, "company_id", socket.assigns.tier_company_id)

    case Fund.create_waterfall_tier(params) do
      {:ok, _} ->
        tiers = Fund.list_waterfall_tiers(String.to_integer(socket.assigns.tier_company_id))
        {:noreply,
         socket
         |> put_flash(:info, "Waterfall tier added")
         |> assign(show_tier_form: false, editing_tier: nil, waterfall_tiers: tiers)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to add waterfall tier")}
    end
  end

  def handle_event("update_tier", %{"tier" => params}, socket) do
    tier = socket.assigns.editing_tier

    case Fund.update_waterfall_tier(tier, params) do
      {:ok, _} ->
        tiers = Fund.list_waterfall_tiers(String.to_integer(socket.assigns.tier_company_id))
        {:noreply,
         socket
         |> put_flash(:info, "Waterfall tier updated")
         |> assign(show_tier_form: false, editing_tier: nil, waterfall_tiers: tiers)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update waterfall tier")}
    end
  end

  def handle_event("delete_tier", %{"id" => id}, socket) do
    tier = Fund.get_waterfall_tier!(String.to_integer(id))

    case Fund.delete_waterfall_tier(tier) do
      {:ok, _} ->
        tiers = Fund.list_waterfall_tiers(String.to_integer(socket.assigns.tier_company_id))
        {:noreply,
         socket
         |> put_flash(:info, "Waterfall tier deleted")
         |> assign(waterfall_tiers: tiers, waterfall_results: nil)}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete waterfall tier")}
    end
  end

  def handle_event("calculate_waterfall", %{"amount" => amount, "capital" => capital}, socket) do
    tiers = socket.assigns.waterfall_tiers

    if tiers == [] do
      {:noreply, put_flash(socket, :error, "Add waterfall tiers first")}
    else
      results = Fund.calculate_waterfall(amount, capital, tiers)
      {:noreply, assign(socket, waterfall_results: results, waterfall_calc_amount: amount, waterfall_calc_capital: capital)}
    end
  end

  @impl true
  def handle_info({_event, _record}, socket) do
    if socket.assigns.tier_company_id != "" do
      tiers = Fund.list_waterfall_tiers(String.to_integer(socket.assigns.tier_company_id))
      {:noreply, assign(socket, waterfall_tiers: tiers)}
    else
      {:noreply, socket}
    end
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
        <div class={"metric-value #{if Money.gte?(@statement.net_income, 0), do: "num-positive", else: "num-negative"}"}>
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
              <td class={"td-num #{if Money.gte?(@statement.net_income, 0), do: "num-positive", else: "num-negative"}"}>
                ${format_number(@statement.net_income)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div class="section" style="margin-top: 2rem;">
      <div class="section-head" style="display: flex; justify-content: space-between; align-items: center;">
        <div>
          <h2>Fund Distribution Waterfall</h2>
          <p class="deck" style="margin-top: 0.25rem;">Configure and calculate LP/GP waterfall distribution tiers</p>
        </div>
        <div style="display: flex; gap: 0.5rem; align-items: center;">
          <form phx-change="filter_tier_company" style="display: flex; align-items: center; gap: 0.5rem;">
            <label class="form-label" style="margin: 0; font-size: 0.85rem;">Company</label>
            <select name="company_id" class="form-select" style="width: auto; padding: 0.3rem 0.5rem;">
              <option value="">Select company</option>
              <%= for c <- @companies do %>
                <option value={c.id} selected={to_string(c.id) == @tier_company_id}>{c.name}</option>
              <% end %>
            </select>
          </form>
          <%= if @can_write && @tier_company_id != "" do %>
            <button class="btn btn-primary" phx-click="show_tier_form">Add Tier</button>
          <% end %>
        </div>
      </div>

      <%= if @tier_company_id != "" do %>
        <div class="panel">
          <table>
            <thead>
              <tr>
                <th>Order</th>
                <th>Name</th>
                <th>Type</th>
                <th class="th-num">Hurdle Rate</th>
                <th class="th-num">LP %</th>
                <th class="th-num">GP %</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              <%= for tier <- @waterfall_tiers do %>
                <tr>
                  <td class="td-mono">{tier.tier_order}</td>
                  <td class="td-name">{tier.name}</td>
                  <td><span class={"tag #{tier_type_tag(tier.tier_type)}"}>{humanize_tier_type(tier.tier_type)}</span></td>
                  <td class="td-num">{if tier.hurdle_rate, do: "#{format_number_2(tier.hurdle_rate)}%", else: "-"}</td>
                  <td class="td-num">{if tier.split_lp_pct, do: "#{format_number_2(tier.split_lp_pct)}%", else: "-"}</td>
                  <td class="td-num">{if tier.split_gp_pct, do: "#{format_number_2(tier.split_gp_pct)}%", else: "-"}</td>
                  <td>
                    <%= if @can_write do %>
                      <div style="display: flex; gap: 0.25rem;">
                        <button phx-click="edit_tier" phx-value-id={tier.id} class="btn btn-secondary btn-sm">Edit</button>
                        <button phx-click="delete_tier" phx-value-id={tier.id} class="btn btn-danger btn-sm" data-confirm="Delete this tier?">Del</button>
                      </div>
                    <% end %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
          <%= if @waterfall_tiers == [] do %>
            <div class="empty-state">
              <p>No waterfall tiers configured for this company.</p>
              <%= if @can_write do %>
                <button class="btn btn-primary" phx-click="show_tier_form">Add First Tier</button>
              <% end %>
            </div>
          <% end %>
        </div>

        <%= if @waterfall_tiers != [] do %>
          <div class="panel" style="margin-top: 1rem; padding: 1rem;">
            <h3 style="margin-bottom: 0.5rem;">Calculate Waterfall Distribution</h3>
            <form phx-submit="calculate_waterfall" style="display: flex; gap: 1rem; align-items: flex-end; flex-wrap: wrap;">
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">Distributable Amount</label>
                <input type="number" name="amount" class="form-input" step="any" value={@waterfall_calc_amount} required style="width: 200px;" />
              </div>
              <div class="form-group" style="margin-bottom: 0;">
                <label class="form-label">Contributed Capital</label>
                <input type="number" name="capital" class="form-input" step="any" value={@waterfall_calc_capital} required style="width: 200px;" />
              </div>
              <button type="submit" class="btn btn-primary">Calculate</button>
            </form>
          </div>
        <% end %>

        <%= if @waterfall_results do %>
          <div class="panel" style="margin-top: 1rem;">
            <table>
              <thead>
                <tr>
                  <th>Tier</th>
                  <th>Type</th>
                  <th class="th-num">LP Amount</th>
                  <th class="th-num">GP Amount</th>
                  <th class="th-num">Total Allocated</th>
                </tr>
              </thead>
              <tbody>
                <%= for result <- @waterfall_results do %>
                  <tr>
                    <td class="td-name">{result.tier_name}</td>
                    <td><span class={"tag #{tier_type_tag(result.tier_type)}"}>{humanize_tier_type(result.tier_type)}</span></td>
                    <td class="td-num num-positive">${format_number_2(result.lp_amount)}</td>
                    <td class="td-num num-positive">${format_number_2(result.gp_amount)}</td>
                    <td class="td-num" style="font-weight: 600;">${format_number_2(result.total_allocated)}</td>
                  </tr>
                <% end %>
                <tr style="font-weight: 600; border-top: 2px solid var(--rule);">
                  <td class="td-name">Total</td>
                  <td></td>
                  <td class="td-num num-positive">${format_number_2(Enum.reduce(@waterfall_results, Decimal.new(0), fn r, acc -> Money.add(acc, r.lp_amount) end))}</td>
                  <td class="td-num num-positive">${format_number_2(Enum.reduce(@waterfall_results, Decimal.new(0), fn r, acc -> Money.add(acc, r.gp_amount) end))}</td>
                  <td class="td-num">${format_number_2(Enum.reduce(@waterfall_results, Decimal.new(0), fn r, acc -> Money.add(acc, r.total_allocated) end))}</td>
                </tr>
              </tbody>
            </table>
          </div>
        <% end %>
      <% else %>
        <div class="panel">
          <div class="empty-state">Select a company to manage waterfall tiers.</div>
        </div>
      <% end %>
    </div>

    <%= if @show_tier_form do %>
      <div class="dialog-overlay" phx-click="close_tier_form">
        <div class="dialog-panel" phx-click="noop">
          <div class="dialog-header">
            <h3>{if @show_tier_form == :edit, do: "Edit Waterfall Tier", else: "Add Waterfall Tier"}</h3>
          </div>
          <div class="dialog-body">
            <form phx-submit={if @show_tier_form == :edit, do: "update_tier", else: "save_tier"}>
              <div class="form-group">
                <label class="form-label">Tier Order *</label>
                <input type="number" name="tier[tier_order]" class="form-input" value={if @editing_tier, do: @editing_tier.tier_order, else: length(@waterfall_tiers) + 1} required />
              </div>
              <div class="form-group">
                <label class="form-label">Name *</label>
                <input type="text" name="tier[name]" class="form-input" value={if @editing_tier, do: @editing_tier.name, else: ""} required />
              </div>
              <div class="form-group">
                <label class="form-label">Description</label>
                <textarea name="tier[description]" class="form-input">{if @editing_tier, do: @editing_tier.description, else: ""}</textarea>
              </div>
              <div class="form-group">
                <label class="form-label">Tier Type *</label>
                <select name="tier[tier_type]" class="form-select" required>
                  <option value="">Select type</option>
                  <option value="return_of_capital" selected={@editing_tier && @editing_tier.tier_type == "return_of_capital"}>Return of Capital</option>
                  <option value="preferred_return" selected={@editing_tier && @editing_tier.tier_type == "preferred_return"}>Preferred Return</option>
                  <option value="catch_up" selected={@editing_tier && @editing_tier.tier_type == "catch_up"}>GP Catch-Up</option>
                  <option value="carried_interest" selected={@editing_tier && @editing_tier.tier_type == "carried_interest"}>Carried Interest</option>
                  <option value="residual" selected={@editing_tier && @editing_tier.tier_type == "residual"}>Residual Split</option>
                </select>
              </div>
              <div class="form-group">
                <label class="form-label">Hurdle Rate (%)</label>
                <input type="number" name="tier[hurdle_rate]" class="form-input" step="any" value={if @editing_tier, do: @editing_tier.hurdle_rate, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">LP Split (%)</label>
                <input type="number" name="tier[split_lp_pct]" class="form-input" step="any" value={if @editing_tier, do: @editing_tier.split_lp_pct, else: ""} />
              </div>
              <div class="form-group">
                <label class="form-label">GP Split (%)</label>
                <input type="number" name="tier[split_gp_pct]" class="form-input" step="any" value={if @editing_tier, do: @editing_tier.split_gp_pct, else: ""} />
              </div>
              <div class="form-actions">
                <button type="submit" class="btn btn-primary">{if @show_tier_form == :edit, do: "Update", else: "Add Tier"}</button>
                <button type="button" phx-click="close_tier_form" class="btn btn-secondary">Cancel</button>
              </div>
            </form>
          </div>
        </div>
      </div>
    <% end %>
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
            [Money.to_float(revenue)] ++
              List.duplicate(0, length(expenses)) ++
              [if(Money.gte?(net, 0), do: Money.to_float(net), else: 0)],
          backgroundColor: "#00994d",
          stack: "waterfall"
        },
        %{
          label: "Expense",
          data:
            [0] ++
              Enum.map(expenses, &Money.to_float(&1.amount)) ++
              [if(Money.negative?(net), do: Money.to_float(Money.abs(net)), else: 0)],
          backgroundColor: "#cc0000",
          stack: "waterfall"
        }
      ]
    }
  end

  defp build_waterfall_bars(revenue, expenses, _net) do
    # Base values: invisible bars that position visible bars at correct heights
    # Revenue bar starts at 0
    # Each expense bar starts at where the previous one ended
    # Net income bar starts at 0

    {_running, expense_bases} =
      Enum.reduce(expenses, {revenue, []}, fn exp, {running, bases} ->
        new_running = Money.sub(running, exp.amount)
        {new_running, bases ++ [Money.to_float(new_running)]}
      end)

    base_values = [0] ++ expense_bases ++ [0]
    value_values = [Money.to_float(revenue)] ++ Enum.map(expenses, &Money.to_float(&1.amount)) ++ [Money.to_float(revenue)]

    {base_values, value_values}
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

  defp format_number_2(%Decimal{} = n),
    do: n |> Decimal.round(2) |> Decimal.to_string() |> add_commas_2()

  defp format_number_2(n) when is_float(n),
    do: :erlang.float_to_binary(n, decimals: 2) |> add_commas_2()

  defp format_number_2(n) when is_integer(n), do: Integer.to_string(n) |> add_commas_2()
  defp format_number_2(nil), do: "0"
  defp format_number_2(_), do: "0"

  defp add_commas_2(str) do
    case String.split(str, ".") do
      [int_part, dec_part] ->
        formatted_int =
          int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()

        "#{formatted_int}.#{dec_part}"

      [int_part] ->
        int_part |> String.reverse() |> String.replace(~r/(\d{3})(?=\d)/, "\\1,") |> String.reverse()
    end
  end

  defp tier_type_tag("return_of_capital"), do: "tag-sky"
  defp tier_type_tag("preferred_return"), do: "tag-lemon"
  defp tier_type_tag("catch_up"), do: "tag-rose"
  defp tier_type_tag("carried_interest"), do: "tag-jade"
  defp tier_type_tag("residual"), do: "tag-jade"
  defp tier_type_tag(_), do: ""

  defp humanize_tier_type("return_of_capital"), do: "Return of Capital"
  defp humanize_tier_type("preferred_return"), do: "Preferred Return"
  defp humanize_tier_type("catch_up"), do: "GP Catch-Up"
  defp humanize_tier_type("carried_interest"), do: "Carried Interest"
  defp humanize_tier_type("residual"), do: "Residual Split"
  defp humanize_tier_type(other), do: other || "Unknown"
end
